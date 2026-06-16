from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.pret import Pret, Echeancier
from app.models.client import Client
from app.models.epargne import CompteEpargne
from datetime import datetime

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
