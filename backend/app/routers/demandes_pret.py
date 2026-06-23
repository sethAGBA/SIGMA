from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime
import uuid

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.pret import DemandePret, Pret, Echeancier
from app.schemas.pret import LoanRequestCreate, LoanRequestStatusUpdate, DisburseRequest

router = APIRouter(prefix="/demandes-pret", tags=["Demandes de prêt"])


@router.get("")
def list_demandes(
    statut: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    """Liste des demandes de prêt avec filtre optionnel ?statut=.
    Retourne HTTP 401 si JWT absent/invalide (géré par get_current_user).
    """
    query = db.query(DemandePret)
    if statut:
        query = query.filter(DemandePret.statut == statut)
    return query.order_by(DemandePret.id.desc()).all()


@router.post("", status_code=status.HTTP_201_CREATED)
def create_demande(
    data: LoanRequestCreate,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    """Crée une demande de prêt.
    Retourne HTTP 201 avec { id, numero_demande, statut }.
    Retourne HTTP 422 si payload invalide (géré par FastAPI/Pydantic).
    Retourne HTTP 401 si JWT absent/invalide (géré par get_current_user).
    """
    # Générer un numéro de demande unique
    numero_demande = (
        f"DEM-{datetime.utcnow().strftime('%Y%m%d')}-"
        f"{str(uuid.uuid4())[:8].upper()}"
    )

    demande = DemandePret(
        client_id=data.client_id,
        produit_id=data.produit_id,
        montant_demande=data.montant_demande,
        duree_mois=data.duree_mois,
        frequence_remboursement=data.frequence_remboursement,
        objet_pret=data.objet_pret,
        mensualite=data.mensualite,
        total_a_rembourser=data.total_a_rembourser,
        cout_total_credit=data.cout_total_credit,
        teg=data.teg,
        revenus_mensuels=data.revenus_mensuels,
        charges_mensuelles=data.charges_mensuelles,
        capacite_remboursement=data.capacite_remboursement,
        taux_effort=data.taux_effort,
        autres_dettes=data.autres_dettes,
        reste_a_vivre=data.reste_a_vivre,
        type_garantie=data.type_garantie,
        description_garantie=data.description_garantie,
        valeur_garantie=data.valeur_garantie,
        caution_personnelle=data.caution_personnelle,
        rapport_visite=data.rapport_visite,
        observations_visite=data.observations_visite,
        photos_visite=data.photos_visite,
        score_calcule=data.score_calcule,
        recommandation_systeme=data.recommandation_systeme,
        avis_agent=data.avis_agent,
        statut=data.statut or "En attente",
    )

    db.add(demande)
    db.commit()
    db.refresh(demande)

    return {
        "id": demande.id,
        "numero_demande": numero_demande,
        "statut": demande.statut,
    }


@router.put("/{demande_id}/statut")
def update_statut_demande(
    demande_id: int,
    data: LoanRequestStatusUpdate,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    """Met à jour le statut d'une demande de prêt.
    Retourne HTTP 404 si la demande n'existe pas.
    Retourne HTTP 401 si JWT absent/invalide.
    Retourne HTTP 422 si payload invalide.
    """
    demande = db.query(DemandePret).filter(DemandePret.id == demande_id).first()
    if not demande:
        raise HTTPException(status_code=404, detail="Demande de prêt introuvable")

    demande.statut = data.statut
    if data.motif_rejet is not None:
        demande.motif_rejet = data.motif_rejet
    demande.date_modification = datetime.utcnow()

    db.commit()
    db.refresh(demande)

    return {"message": f"Statut mis à jour : {data.statut}", "id": demande.id, "statut": demande.statut}


@router.post("/{demande_id}/debloquer", status_code=status.HTTP_201_CREATED)
async def debloquer_demande(
    demande_id: int,
    data: DisburseRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Déblocage d'une demande de prêt : opération atomique PostgreSQL.
    Crée le Pret + Echeancier + met à jour le statut de la demande.
    Déclenche AutomaticAccountingService.on_deblocage_pret().
    Retourne HTTP 201 avec { loan_id, numero_pret }.
    Retourne HTTP 404 si la demande n'existe pas.
    Retourne HTTP 401 si JWT absent/invalide.
    Retourne HTTP 422 si payload invalide.
    """
    # 1. Vérifier que la demande existe
    demande = db.query(DemandePret).filter(DemandePret.id == demande_id).first()
    if not demande:
        raise HTTPException(status_code=404, detail="Demande de prêt introuvable")

    # 2. Générer un numéro de prêt unique
    numero_pret = (
        f"PRE-{datetime.utcnow().strftime('%Y%m%d')}-"
        f"{str(uuid.uuid4())[:8].upper()}"
    )

    date_deblocage = data.date_deblocage or datetime.utcnow()

    # 3. Opération atomique : Pret + Echeancier + mise à jour statut demande
    # SQLAlchemy gère la transaction via l'unit-of-work ; en cas d'erreur,
    # le rollback est appelé automatiquement par le gestionnaire de session.
    try:
        # Créer le prêt
        pret = Pret(
            demande_pret_id=demande_id,
            client_id=demande.client_id,
            produit_id=demande.produit_id,
            numero_pret=numero_pret,
            montant_initial=data.montant_initial,
            solde_restant=data.montant_initial,
            date_deblocage=date_deblocage,
            statut="En cours",
            agent_gestionnaire=data.agent_gestionnaire or (current_user.username if current_user else None),
            agence_gestion=data.agence_gestion,
        )
        db.add(pret)
        db.flush()  # Obtenir pret.id sans commit pour lier l'échéancier

        # Créer les lignes d'échéancier si fournies
        if data.echeancier:
            for ech_data in data.echeancier:
                echeance = Echeancier(
                    pret_id=pret.id,
                    numero_echeance=ech_data.numero_echeance,
                    date_prevue=ech_data.date_prevue,
                    capital_du=ech_data.capital_du,
                    interets_dus=ech_data.interets_dus,
                    frais_dus=ech_data.frais_dus or 0.0,
                    total_du=ech_data.total_du,
                    capital_restant=ech_data.capital_restant,
                    statut=ech_data.statut or "En attente",
                    total_paye=0.0,
                    capital_paye=0.0,
                    interets_payes=0.0,
                    frais_payes=0.0,
                )
                db.add(echeance)

        # Mettre à jour le statut de la demande
        demande.statut = "Débloquée"
        demande.date_modification = datetime.utcnow()

        db.commit()
        db.refresh(pret)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Erreur lors du déblocage — transaction annulée",
        )

    # 4. Pont comptable automatique (hors transaction DB principale)
    from app.services.accounting_service import AutomaticAccountingService
    await AutomaticAccountingService().on_deblocage_pret(
        pret_id=pret.id,
        montant=pret.montant_initial,
        agent=current_user.username,
        db=db,
    )

    return {"loan_id": pret.id, "numero_pret": pret.numero_pret}
