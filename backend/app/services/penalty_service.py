"""
PenaltyService — Calcul automatique des pénalités de retard.

Logique : Pour chaque échéance non soldée dont la date_prevue est dépassée,
calculer jours_retard = (aujourd'hui - date_prevue).days et appliquer le
taux de pénalité journalier défini dans le produit financier.
"""
from datetime import datetime, date
from sqlalchemy.orm import Session
from sqlalchemy import and_
from app.models.pret import Echeancier, Pret
from app.models.produit_financier import ProduitFinancier


TAUX_PENALITE_JOURNALIER_DEFAUT = 0.001  # 0.1% par jour de retard par défaut


class PenaltyService:

    async def calculate_and_apply_penalties(self, db: Session) -> dict:
        """
        Scanne tous les écheanciers non soldés et met à jour les pénalités.
        Retourne un résumé du nombre d'échéances traitées.
        """
        today = datetime.utcnow().date()
        count_updated = 0
        total_penalites = 0.0

        # Récupérer les échéances en retard non payées
        echeances_en_retard = db.query(Echeancier).join(
            Pret, Echeancier.pret_id == Pret.id
        ).filter(
            and_(
                Echeancier.statut != "Payé",
                Echeancier.date_prevue < datetime.combine(today, datetime.min.time()),
            )
        ).all()

        for echeance in echeances_en_retard:
            date_prevue = echeance.date_prevue.date() if echeance.date_prevue else today
            jours_retard = (today - date_prevue).days

            if jours_retard <= 0:
                continue

            # Récupérer le taux de pénalité du produit
            pret = db.query(Pret).filter(Pret.id == echeance.pret_id).first()
            taux = TAUX_PENALITE_JOURNALIER_DEFAUT

            capital_restant = echeance.capital_restant or echeance.capital_du or 0
            penalite = round(capital_restant * taux * jours_retard, 0)

            # Mettre à jour les frais (pénalités) de l'échéance
            echeance.frais_dus = penalite
            echeance.total_du = (echeance.capital_du or 0) + (echeance.interets_dus or 0) + penalite

            # Mettre à jour le compteur de jours retard sur le prêt
            if pret and (pret.jours_retard or 0) < jours_retard:
                pret.jours_retard = jours_retard

            total_penalites += penalite
            count_updated += 1

        db.commit()

        return {
            "echeances_traitees": count_updated,
            "total_penalites_calcule": total_penalites,
            "date_calcul": today.isoformat(),
        }
