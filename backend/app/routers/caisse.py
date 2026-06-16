from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from datetime import datetime, date
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.caisse import OperationCaisse, ClotureCaisse
from app.schemas.caisse import (
    OperationCaisseCreate, OperationCaisseResponse,
    ClotureCaisseCreate, ClotureCaisseResponse,
)

router = APIRouter(prefix="/caisse", tags=["Caisse"])


@router.get("/operations", response_model=list[OperationCaisseResponse])
def list_operations(
    date_debut: date = Query(default=None),
    date_fin: date = Query(default=None),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(OperationCaisse)
    if date_debut:
        query = query.filter(OperationCaisse.date_operation >= datetime.combine(date_debut, datetime.min.time()))
    if date_fin:
        query = query.filter(OperationCaisse.date_operation <= datetime.combine(date_fin, datetime.max.time()))
    return query.order_by(OperationCaisse.date_operation.desc()).all()


@router.post("/operations", response_model=OperationCaisseResponse, status_code=status.HTTP_201_CREATED)
def create_operation(
    data: OperationCaisseCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    op = OperationCaisse(**data.model_dump())
    op.agent_operation = current_user.username
    db.add(op)
    db.commit()
    db.refresh(op)
    return op


@router.get("/solde")
def get_solde(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Calcule le solde courant de la caisse."""
    from sqlalchemy import func
    result = db.query(
        func.sum(OperationCaisse.montant).filter(OperationCaisse.type_operation == "ENTREE").label("entrees"),
        func.sum(OperationCaisse.montant).filter(OperationCaisse.type_operation == "SORTIE").label("sorties"),
    ).one()
    entrees = result.entrees or 0.0
    sorties = result.sorties or 0.0
    return {"solde": entrees - sorties, "entrees": entrees, "sorties": sorties}


@router.post("/clotures", response_model=ClotureCaisseResponse, status_code=status.HTTP_201_CREATED)
def cloture_caisse(
    data: ClotureCaisseCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from sqlalchemy import func
    today = datetime.utcnow().date()
    result = db.query(
        func.sum(OperationCaisse.montant).filter(OperationCaisse.type_operation == "ENTREE").label("entrees"),
        func.sum(OperationCaisse.montant).filter(OperationCaisse.type_operation == "SORTIE").label("sorties"),
    ).one()
    entrees = result.entrees or 0.0
    sorties = result.sorties or 0.0
    solde_theorique = entrees - sorties

    cloture = ClotureCaisse(
        agent_cloture=current_user.username,
        total_entrees=entrees,
        total_sorties=sorties,
        solde_theorique=solde_theorique,
        solde_physique=data.solde_physique,
        ecart=data.solde_physique - solde_theorique,
        observations=data.observations,
        billetage=data.billetage,
    )
    db.add(cloture)
    db.commit()
    db.refresh(cloture)
    return cloture


@router.get("/clotures", response_model=list[ClotureCaisseResponse])
def list_clotures(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(ClotureCaisse).order_by(ClotureCaisse.date_cloture.desc()).all()
