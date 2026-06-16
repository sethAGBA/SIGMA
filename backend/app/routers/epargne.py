from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.epargne import CompteEpargne, TransactionEpargne
from app.schemas.epargne import CompteEpargneCreate, CompteEpargneResponse, TransactionCreate

router = APIRouter(prefix="/epargne", tags=["Épargne"])


@router.get("/comptes", response_model=list[CompteEpargneResponse])
def list_comptes(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(CompteEpargne).order_by(CompteEpargne.date_ouverture.desc()).all()


@router.post("/comptes", response_model=CompteEpargneResponse, status_code=status.HTTP_201_CREATED)
def ouvrir_compte(data: CompteEpargneCreate, db: Session = Depends(get_db), _=Depends(get_current_user)):
    existing = db.query(CompteEpargne).filter(CompteEpargne.numero_compte == data.numero_compte).first()
    if existing:
        raise HTTPException(status_code=400, detail="Numéro de compte déjà utilisé")
    compte = CompteEpargne(**data.model_dump())
    db.add(compte)
    db.commit()
    db.refresh(compte)
    return compte


@router.get("/comptes/{compte_id}", response_model=CompteEpargneResponse)
def get_compte(compte_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    compte = db.query(CompteEpargne).filter(CompteEpargne.id == compte_id).first()
    if not compte:
        raise HTTPException(status_code=404, detail="Compte introuvable")
    return compte


@router.post("/transactions", status_code=status.HTTP_201_CREATED)
async def effectuer_transaction(
    data: TransactionCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    compte = db.query(CompteEpargne).filter(CompteEpargne.id == data.compte_id).first()
    if not compte:
        raise HTTPException(status_code=404, detail="Compte introuvable")

    if data.type_operation == "RETRAIT":
        if compte.solde < data.montant:
            raise HTTPException(status_code=400, detail="Solde insuffisant")
        compte.solde -= data.montant
    elif data.type_operation == "DEPOT":
        compte.solde += data.montant
    else:
        raise HTTPException(status_code=400, detail="Type d'opération invalide : DEPOT ou RETRAIT")

    transaction = TransactionEpargne(
        compte_id=data.compte_id,
        type_operation=data.type_operation,
        montant=data.montant,
        solde_apres=compte.solde,
        agent_operation=current_user.username,
        commentaire=data.commentaire,
    )
    db.add(transaction)
    db.commit()
    db.refresh(transaction)

    # Pont comptable automatique
    from app.services.accounting_service import AutomaticAccountingService
    svc = AutomaticAccountingService()
    if data.type_operation == "DEPOT":
        await svc.on_depot_epargne(compte_id=data.compte_id, montant=data.montant, agent=current_user.username, db=db)
    else:
        await svc.on_retrait_epargne(compte_id=data.compte_id, montant=data.montant, agent=current_user.username, db=db)

    return {"message": "Transaction enregistrée", "solde": compte.solde, "id": transaction.id}


@router.get("/comptes/{compte_id}/transactions")
def get_transactions(compte_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(TransactionEpargne).filter(
        TransactionEpargne.compte_id == compte_id
    ).order_by(TransactionEpargne.date_operation.desc()).all()
