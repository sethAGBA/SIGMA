from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.pret import Pret, Echeancier
from app.models.client import Client
from app.models.epargne import CompteEpargne
from app.models.remboursement import Remboursement, ActionRecouvrement
from datetime import datetime
from typing import Optional

router = APIRouter(prefix="/reporting", tags=["Reporting"])


@router.get("/dashboard")
def get_dashboard_data(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Indicateurs clés pour le tableau de bord."""
    total_prets_actifs = db.query(func.count(Pret.id)).filter(Pret.statut == "En cours").scalar() or 0
    encours_total = db.query(func.sum(Pret.solde_restant)).filter(Pret.statut == "En cours").scalar() or 0
    clients_actifs = db.query(func.count(Client.id)).filter(Client.statut == "Actif").scalar() or 0
    total_epargne = db.query(func.sum(CompteEpargne.solde)).filter(CompteEpargne.statut == "Actif").scalar() or 0

    # PAR : prêts avec retard
    prets_en_retard = db.query(func.count(Pret.id)).filter(Pret.jours_retard > 0, Pret.statut == "En cours").scalar() or 0
    taux_remboursement = round((1 - prets_en_retard / max(total_prets_actifs, 1)) * 100, 2)

    return {
        "encours_total": encours_total,
        "clients_actifs": clients_actifs,
        "prets_actifs": total_prets_actifs,
        "total_epargne": total_epargne,
        "prets_en_retard": prets_en_retard,
        "taux_remboursement": taux_remboursement,
        "date": datetime.utcnow().isoformat(),
    }


@router.get("/par")
def get_par_stats(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Statistiques Portfolio At Risk."""
    prets = db.query(Pret).filter(Pret.statut == "En cours").all()

    encours_total = sum(p.solde_restant or 0 for p in prets)
    par_sains = sum(p.solde_restant or 0 for p in prets if (p.jours_retard or 0) == 0)
    par_1 = sum(p.solde_restant or 0 for p in prets if 1 <= (p.jours_retard or 0) <= 30)
    par_30 = sum(p.solde_restant or 0 for p in prets if 31 <= (p.jours_retard or 0) <= 90)
    par_90 = sum(p.solde_restant or 0 for p in prets if 91 <= (p.jours_retard or 0) <= 180)
    par_180 = sum(p.solde_restant or 0 for p in prets if (p.jours_retard or 0) > 180)

    return {
        "encours_total": encours_total,
        "par_sains": par_sains,
        "par_1": par_1,
        "par_30": par_30,
        "par_90": par_90,
        "par_180": par_180,
        "taux_par_30": round(par_30 / max(encours_total, 1) * 100, 2),
        "taux_par_90": round(par_90 / max(encours_total, 1) * 100, 2),
        "nb_prets": len(prets),
        "nb_en_retard": sum(1 for p in prets if (p.jours_retard or 0) > 0),
    }


@router.get("/executive")
def get_executive_stats(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Statistiques exécutives agrégées pour le tableau de bord de direction."""
    # Activity metrics
    total_prets_actifs = db.query(func.count(Pret.id)).filter(Pret.statut == "En cours").scalar() or 0
    total_clients = db.query(func.count(Client.id)).scalar() or 0
    clients_actifs = db.query(func.count(Client.id)).filter(Client.statut == "Actif").scalar() or 0
    total_remboursements = db.query(func.count(Remboursement.id)).scalar() or 0

    # Portfolio metrics
    encours_total = db.query(func.sum(Pret.solde_restant)).filter(Pret.statut == "En cours").scalar() or 0
    montant_debourse_total = db.query(func.sum(Pret.montant_initial)).scalar() or 0
    prets_en_retard = db.query(func.count(Pret.id)).filter(Pret.jours_retard > 0, Pret.statut == "En cours").scalar() or 0
    par_ratio = round(prets_en_retard / max(total_prets_actifs, 1) * 100, 2)

    # Quality metrics
    taux_remboursement = round((1 - prets_en_retard / max(total_prets_actifs, 1)) * 100, 2)
    prets_termines = db.query(func.count(Pret.id)).filter(Pret.statut == "Terminé").scalar() or 0

    # Savings metrics
    total_epargne = db.query(func.sum(CompteEpargne.solde)).filter(CompteEpargne.statut == "Actif").scalar() or 0
    nb_comptes_epargne = db.query(func.count(CompteEpargne.id)).filter(CompteEpargne.statut == "Actif").scalar() or 0

    # Top agents by number of active loans managed
    top_agents_rows = (
        db.query(Pret.agent_gestionnaire, func.count(Pret.id).label("nb_prets"))
        .filter(Pret.statut == "En cours", Pret.agent_gestionnaire.isnot(None))
        .group_by(Pret.agent_gestionnaire)
        .order_by(func.count(Pret.id).desc())
        .limit(5)
        .all()
    )
    top_agents = [{"agent": row.agent_gestionnaire, "nb_prets": row.nb_prets} for row in top_agents_rows]

    return {
        "activity": {
            "total_prets_actifs": total_prets_actifs,
            "total_clients": total_clients,
            "clients_actifs": clients_actifs,
            "total_remboursements": total_remboursements,
            "prets_termines": prets_termines,
        },
        "portfolio": {
            "encours_total": encours_total,
            "montant_debourse_total": montant_debourse_total,
            "prets_en_retard": prets_en_retard,
            "par_ratio": par_ratio,
        },
        "quality": {
            "taux_remboursement": taux_remboursement,
            "par_ratio": par_ratio,
            "nb_prets_sains": total_prets_actifs - prets_en_retard,
            "nb_prets_en_retard": prets_en_retard,
        },
        "savings": {
            "total_epargne": total_epargne,
            "nb_comptes_epargne": nb_comptes_epargne,
        },
        "top_agents": top_agents,
        "last_update": datetime.utcnow().isoformat(),
    }


@router.get("/delinquents")
def get_delinquent_loans(
    par_category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    """Liste des prêts en souffrance avec filtre optionnel par catégorie PAR."""
    query = db.query(Pret).filter(Pret.jours_retard > 0, Pret.statut == "En cours")

    if par_category:
        category = par_category.upper()
        if category == "PAR1":
            query = query.filter(Pret.jours_retard >= 1, Pret.jours_retard <= 30)
        elif category == "PAR30":
            query = query.filter(Pret.jours_retard >= 31, Pret.jours_retard <= 90)
        elif category == "PAR90":
            query = query.filter(Pret.jours_retard >= 91, Pret.jours_retard <= 180)
        elif category == "PAR180":
            query = query.filter(Pret.jours_retard > 180)

    prets = query.all()

    result = []
    for pret in prets:
        result.append({
            "id": pret.id,
            "numero_pret": pret.numero_pret,
            "client_id": pret.client_id,
            "montant_initial": pret.montant_initial,
            "solde_restant": pret.solde_restant,
            "date_deblocage": pret.date_deblocage.isoformat() if pret.date_deblocage else None,
            "date_echeance_prochaine": pret.date_echeance_prochaine.isoformat() if pret.date_echeance_prochaine else None,
            "jours_retard": pret.jours_retard,
            "statut": pret.statut,
            "agent_gestionnaire": pret.agent_gestionnaire,
            "agence_gestion": pret.agence_gestion,
        })

    return result


@router.get("/delinquent/{loan_id}")
def get_delinquent_loan_detail(
    loan_id: int,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    """Détail complet d'un prêt en souffrance avec client, échéancier impayé et actions de recouvrement."""
    pret = db.query(Pret).filter(Pret.id == loan_id).first()
    if not pret:
        raise HTTPException(status_code=404, detail="Prêt introuvable")

    # Client data
    client = db.query(Client).filter(Client.id == pret.client_id).first()
    client_data = None
    if client:
        client_data = {
            "id": client.id,
            "numero_client": client.numero_client,
            "nom": client.nom,
            "prenoms": client.prenoms,
            "telephone": client.telephone,
            "email": client.email,
            "adresse": client.adresse,
            "statut": client.statut,
        }

    # Unpaid schedules (statut != 'Payé' or total_paye < total_du)
    echeances = (
        db.query(Echeancier)
        .filter(Echeancier.pret_id == loan_id, Echeancier.statut != "Payé")
        .order_by(Echeancier.numero_echeance)
        .all()
    )
    unpaid_schedules = []
    for e in echeances:
        unpaid_schedules.append({
            "id": e.id,
            "numero_echeance": e.numero_echeance,
            "date_prevue": e.date_prevue.isoformat() if e.date_prevue else None,
            "capital_du": e.capital_du,
            "interets_dus": e.interets_dus,
            "frais_dus": e.frais_dus,
            "total_du": e.total_du,
            "capital_paye": e.capital_paye,
            "interets_payes": e.interets_payes,
            "total_paye": e.total_paye,
            "capital_restant": e.capital_restant,
            "statut": e.statut,
            "date_effectuee": e.date_effectuee.isoformat() if e.date_effectuee else None,
        })

    # Recovery actions
    actions = (
        db.query(ActionRecouvrement)
        .filter(ActionRecouvrement.pret_id == loan_id)
        .order_by(ActionRecouvrement.date_action.desc())
        .all()
    )
    recovery_actions = [
        {
            "id": a.id,
            "date_action": a.date_action.isoformat() if a.date_action else None,
            "type_action": a.type_action,
            "description": a.description,
            "agent_name": a.agent_name,
            "resultat": a.resultat,
        }
        for a in actions
    ]

    # Accumulated penalties: sum of part_penalites from repayments
    penalites_accumulees = (
        db.query(func.sum(Remboursement.part_penalites))
        .filter(Remboursement.pret_id == loan_id)
        .scalar()
        or 0.0
    )

    # Provision constituée: simple provisioning rule based on PAR category
    jours_retard = pret.jours_retard or 0
    solde_restant = pret.solde_restant or 0.0
    if jours_retard <= 30:
        taux_provision = 0.10
    elif jours_retard <= 90:
        taux_provision = 0.25
    elif jours_retard <= 180:
        taux_provision = 0.50
    else:
        taux_provision = 1.00
    provision_constituee = round(solde_restant * taux_provision, 2)

    return {
        "loan": {
            "id": pret.id,
            "numero_pret": pret.numero_pret,
            "client_id": pret.client_id,
            "montant_initial": pret.montant_initial,
            "solde_restant": pret.solde_restant,
            "date_deblocage": pret.date_deblocage.isoformat() if pret.date_deblocage else None,
            "date_echeance_prochaine": pret.date_echeance_prochaine.isoformat() if pret.date_echeance_prochaine else None,
            "jours_retard": jours_retard,
            "statut": pret.statut,
            "agent_gestionnaire": pret.agent_gestionnaire,
            "agence_gestion": pret.agence_gestion,
        },
        "client": client_data,
        "unpaid_schedules": unpaid_schedules,
        "recovery_actions": recovery_actions,
        "penalites_accumulees": penalites_accumulees,
        "provision_constituee": provision_constituee,
        "jours_retard": jours_retard,
    }
