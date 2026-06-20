from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
import uuid
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.remboursement import Remboursement
from app.models.pret import Pret, Echeancier
from app.schemas.pret import RemboursementCreate

router = APIRouter(prefix="/remboursements", tags=["Remboursements"])


@router.post("", status_code=status.HTTP_201_CREATED)
async def enregistrer_remboursement(
    data: RemboursementCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    # Vérifier le prêt
    pret = db.query(Pret).filter(Pret.id == data.pret_id).first()
    if not pret:
        raise HTTPException(status_code=404, detail="Prêt introuvable")

    if data.numero_recu:
        existing = (
            db.query(Remboursement)
            .filter(Remboursement.numero_recu == data.numero_recu)
            .first()
        )
        if existing:
            raise HTTPException(
                status_code=409,
                detail={
                    "server_payload": {
                        "id": existing.id,
                        "numero_recu": existing.numero_recu,
                        "montant_total": existing.montant_total,
                        "pret_id": existing.pret_id,
                    },
                    "server_updated_at": (
                        existing.date_paiement.isoformat()
                        if existing.date_paiement
                        else None
                    ),
                },
            )

    # Générer un numéro de reçu unique si absent
    numero_recu = data.numero_recu or (
        f"REC-{datetime.utcnow().strftime('%Y%m%d')}-"
        f"{str(uuid.uuid4())[:8].upper()}"
    )

    remboursement = Remboursement(
        pret_id=data.pret_id,
        echeance_id=data.echeance_id,
        montant_total=data.montant_total,
        part_capital=data.part_capital,
        part_interets=data.part_interets,
        part_penalites=data.part_penalites or 0.0,
        mode_paiement=data.mode_paiement,
        numero_recu=numero_recu,
        agent_collecteur=current_user.username,
        commentaire=data.commentaire,
    )
    db.add(remboursement)

    # Mettre à jour le solde restant du prêt
    pret.solde_restant = max(0, (pret.solde_restant or 0) - data.part_capital)
    if pret.solde_restant == 0:
        pret.statut = "Soldé"

    # Mettre à jour le statut de l'échéance
    if data.echeance_id:
        echeance = db.query(Echeancier).filter(Echeancier.id == data.echeance_id).first()
        if echeance:
            echeance.capital_paye = (echeance.capital_paye or 0) + data.part_capital
            echeance.interets_payes = (echeance.interets_payes or 0) + data.part_interets
            echeance.total_paye = (echeance.total_paye or 0) + data.montant_total
            if echeance.total_paye >= (echeance.total_du or 0):
                echeance.statut = "Payé"
                echeance.date_effectuee = datetime.utcnow()

    db.commit()
    db.refresh(remboursement)

    # Pont comptable automatique
    from app.services.accounting_service import AutomaticAccountingService
    await AutomaticAccountingService().on_remboursement(  # Phase 3 OK
        remboursement_id=remboursement.id,
        part_capital=data.part_capital,
        part_interets=data.part_interets,
        part_penalites=data.part_penalites or 0.0,
        agent=current_user.username,
        db=db,
    )

    return {"message": "Remboursement enregistré", "numero_recu": numero_recu, "id": remboursement.id}


@router.get("")
def list_remboursements(
    pret_id: int = None,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(Remboursement)
    if pret_id:
        query = query.filter(Remboursement.pret_id == pret_id)
    return query.order_by(Remboursement.date_paiement.desc()).all()
