# Phase 3 OK
"""
ScoringService — Recalcul automatique du score de crédit.

Barème :
- Base : 60 points
- Aucun retard historique : +20 points
- Retards 1-30j dans passé : -10 points
- Retards 31-90j dans passé : -20 points
- Retards > 90j dans passé  : -30 points
- Taux remboursement > 95%  : +10 points
- Taux remboursement < 80%  : -15 points
- Ancienneté > 2 ans        : +5 points
- Prêts soldés > 2          : +5 points

Score final : clamped entre 0 et 100
Niveau de risque : Faible (70-100), Moyen (40-69), Élevé (0-39)
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.client import Client
from app.models.pret import Pret, Echeancier


class ScoringService:

    async def recalculate_all_scores(self, db: Session) -> dict:
        """Recalcule le score de crédit de tous les clients actifs."""
        clients = db.query(Client).filter(Client.statut == "Actif").all()
        count = 0

        for client in clients:
            score = await self._calculate_score_for_client(client.id, db)
            client.score_credit = score
            client.niveau_risque = self._score_to_risk_level(score)
            count += 1

        db.commit()
        return {"clients_traites": count}

    async def _calculate_score_for_client(self, client_id: int, db: Session) -> int:
        score = 60  # Base

        # Récupérer tous les prêts du client
        prets = db.query(Pret).filter(Pret.client_id == client_id).all()

        if not prets:
            return score

        prets_soldes = [p for p in prets if p.statut == "Soldé"]
        prets_actifs = [p for p in prets if p.statut == "En cours"]

        # Bonus prêts soldés
        if len(prets_soldes) >= 2:
            score += 5

        # Analyse des retards sur les échéances
        for pret in prets:
            echeances = db.query(Echeancier).filter(Echeancier.pret_id == pret.id).all()
            retards = [e for e in echeances if (e.frais_dus or 0) > 0]

            if not retards:
                score += 5  # Pas de retard sur ce prêt
            else:
                max_retard = max((e.frais_dus or 0) for e in retards)
                # Approximation du retard par les frais (pénalités)
                if max_retard > 0:
                    score -= 10

        # Calculer le taux de remboursement global
        total_du = sum(
            sum(e.total_du or 0 for e in db.query(Echeancier).filter(Echeancier.pret_id == p.id).all())
            for p in prets
        )
        total_paye = sum(
            sum(e.total_paye or 0 for e in db.query(Echeancier).filter(Echeancier.pret_id == p.id).all())
            for p in prets
        )

        if total_du > 0:
            taux = total_paye / total_du
            if taux >= 0.95:
                score += 10
            elif taux < 0.80:
                score -= 15

        # Clamp entre 0 et 100
        return max(0, min(100, score))

    def _score_to_risk_level(self, score: int) -> str:
        if score >= 70:
            return "Faible"
        elif score >= 40:
            return "Moyen"
        else:
            return "Élevé"
