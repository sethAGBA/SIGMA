from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.comptabilite import Ecriture, LigneEcriture, CompteComptable, Journal
from app.schemas.comptabilite import EcritureCreate, EcritureResponse

router = APIRouter(prefix="/comptabilite", tags=["Comptabilité"])


@router.get("/comptes")
def list_comptes(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(CompteComptable).order_by(CompteComptable.numero).all()


@router.get("/journaux")
def list_journaux(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(Journal).all()


@router.get("/ecritures", response_model=list[EcritureResponse])
def list_ecritures(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(Ecriture).order_by(Ecriture.date_comptable.desc()).limit(200).all()


@router.post("/ecritures", response_model=EcritureResponse, status_code=status.HTTP_201_CREATED)
def create_ecriture(
    data: EcritureCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    # Vérifier l'équilibre débit/crédit
    total_debit = sum(l.debit for l in data.lignes)
    total_credit = sum(l.credit for l in data.lignes)
    if abs(total_debit - total_credit) > 0.01:
        raise HTTPException(status_code=400, detail="Écriture non équilibrée (débit ≠ crédit)")

    ecriture = Ecriture(
        date_comptable=data.date_comptable,
        journal_code=data.journal_code,
        numero_piece=data.numero_piece,
        libelle=data.libelle,
        agent_saisie=current_user.username,
        statut="VALIDE",
    )
    db.add(ecriture)
    db.flush()

    for ligne in data.lignes:
        db.add(LigneEcriture(ecriture_id=ecriture.id, **ligne.model_dump()))

    db.commit()
    db.refresh(ecriture)
    return ecriture


@router.get("/ecritures/{ecriture_id}/lignes")
def get_lignes(ecriture_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(LigneEcriture).filter(LigneEcriture.ecriture_id == ecriture_id).all()


@router.get("/balance")
def get_balance(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Balance de vérification — totaux débit/crédit par compte."""
    from sqlalchemy import func
    rows = db.query(
        LigneEcriture.compte_numero,
        func.sum(LigneEcriture.debit).label("total_debit"),
        func.sum(LigneEcriture.credit).label("total_credit"),
    ).group_by(LigneEcriture.compte_numero).order_by(LigneEcriture.compte_numero).all()

    return [
        {
            "compte": r.compte_numero,
            "total_debit": r.total_debit or 0,
            "total_credit": r.total_credit or 0,
            "solde": (r.total_debit or 0) - (r.total_credit or 0),
        }
        for r in rows
    ]
