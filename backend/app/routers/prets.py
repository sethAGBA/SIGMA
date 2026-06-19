from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime
import uuid
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.pret import Pret, Echeancier, DemandePret
from app.models.remboursement import Remboursement
from app.schemas.pret import PretCreate, PretResponse, EcheancierResponse, RemboursementCreate

router = APIRouter(prefix="/prets", tags=["Prêts"])


@router.get("", response_model=list[PretResponse])
def list_prets(
    statut: Optional[str] = Query(None),
    agent: Optional[str] = Query(None),
    agence: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(Pret)
    if statut:
        query = query.filter(Pret.statut == statut)
    if agent:
        query = query.filter(Pret.agent_gestionnaire == agent)
    if agence:
        query = query.filter(Pret.agence_gestion == agence)
    return query.order_by(Pret.id.desc()).all()


@router.post("", response_model=PretResponse, status_code=status.HTTP_201_CREATED)
async def create_pret(
    data: PretCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    pret = Pret(**data.model_dump())
    pret.solde_restant = data.montant_initial
    db.add(pret)
    db.commit()
    db.refresh(pret)

    # Déclencher le pont comptable automatique
    from app.services.accounting_service import AutomaticAccountingService
    await AutomaticAccountingService().on_deblocage_pret(  # Phase 3 OK
        pret_id=pret.id,
        montant=pret.montant_initial,
        agent=current_user.username,
        db=db,
    )

    return pret


@router.get("/{pret_id}", response_model=PretResponse)
def get_pret(pret_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    pret = db.query(Pret).filter(Pret.id == pret_id).first()
    if not pret:
        raise HTTPException(status_code=404, detail="Prêt introuvable")
    return pret


@router.put("/{pret_id}/statut")
def update_statut_pret(
    pret_id: int,
    statut: str,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    pret = db.query(Pret).filter(Pret.id == pret_id).first()
    if not pret:
        raise HTTPException(status_code=404, detail="Prêt introuvable")
    pret.statut = statut
    db.commit()
    return {"message": f"Statut mis à jour : {statut}"}


@router.get("/{pret_id}/echeancier", response_model=list[EcheancierResponse])
def get_echeancier(pret_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    echeances = db.query(Echeancier).filter(
        Echeancier.pret_id == pret_id
    ).order_by(Echeancier.numero_echeance).all()
    return echeances


@router.get("/collecte/jour", response_model=list[EcheancierResponse])
def get_collecte_jour(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Retourne les échéances en retard ou dues aujourd'hui."""
    today = datetime.utcnow().date()
    echeances = db.query(Echeancier).filter(
        Echeancier.statut != "Payé",
        Echeancier.date_prevue <= datetime.combine(today, datetime.max.time()),
    ).all()
    return echeances
