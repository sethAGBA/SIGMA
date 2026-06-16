"""
AutomaticAccountingService — Pont comptable automatique SIGMA.

Génère les écritures comptables pour chaque opération financière :
- Déblocage prêt    : Débit 501 (Crédits clientèle)  / Crédit 530 (Caisse)
- Remboursement     : Débit 530 (Caisse)              / Crédit 501 + 701 + 703
- Dépôt épargne     : Débit 530 (Caisse)              / Crédit 521 (Épargne à vue)
- Retrait épargne   : Débit 521 (Épargne à vue)       / Crédit 530 (Caisse)
"""
from datetime import datetime
from sqlalchemy.orm import Session
from app.models.comptabilite import Ecriture, LigneEcriture


class AutomaticAccountingService:

    async def on_deblocage_pret(self, pret_id: int, montant: float, agent: str, db: Session):
        """Déblocage prêt : Débit 501 / Crédit 530."""
        await self._create_ecriture(
            journal_code="CAISSE",
            libelle=f"Déblocage prêt #{pret_id}",
            agent_saisie=agent,
            lignes=[
                {"compte_numero": "501", "libelle_ligne": f"Crédit à la clientèle — prêt #{pret_id}", "debit": montant, "credit": 0},
                {"compte_numero": "530", "libelle_ligne": f"Caisse — décaissement prêt #{pret_id}", "debit": 0, "credit": montant},
            ],
            db=db,
        )

    async def on_remboursement(
        self,
        remboursement_id: int,
        part_capital: float,
        part_interets: float,
        part_penalites: float,
        agent: str,
        db: Session,
    ):
        """Remboursement : Débit 530 / Crédit 501 + 701 + 703."""
        total = part_capital + part_interets + part_penalites
        lignes = [
            {"compte_numero": "530", "libelle_ligne": f"Caisse — remboursement #{remboursement_id}", "debit": total, "credit": 0},
        ]
        if part_capital > 0:
            lignes.append({"compte_numero": "501", "libelle_ligne": "Capital remboursé", "debit": 0, "credit": part_capital})
        if part_interets > 0:
            lignes.append({"compte_numero": "701", "libelle_ligne": "Intérêts sur prêts", "debit": 0, "credit": part_interets})
        if part_penalites > 0:
            lignes.append({"compte_numero": "703", "libelle_ligne": "Pénalités de retard", "debit": 0, "credit": part_penalites})

        await self._create_ecriture(
            journal_code="CAISSE",
            libelle=f"Remboursement #{remboursement_id}",
            agent_saisie=agent,
            lignes=lignes,
            db=db,
        )

    async def on_depot_epargne(self, compte_id: int, montant: float, agent: str, db: Session):
        """Dépôt épargne : Débit 530 / Crédit 521."""
        await self._create_ecriture(
            journal_code="CAISSE",
            libelle=f"Dépôt épargne — compte #{compte_id}",
            agent_saisie=agent,
            lignes=[
                {"compte_numero": "530", "libelle_ligne": "Caisse — dépôt épargne", "debit": montant, "credit": 0},
                {"compte_numero": "521", "libelle_ligne": f"Épargne à vue — compte #{compte_id}", "debit": 0, "credit": montant},
            ],
            db=db,
        )

    async def on_retrait_epargne(self, compte_id: int, montant: float, agent: str, db: Session):
        """Retrait épargne : Débit 521 / Crédit 530."""
        await self._create_ecriture(
            journal_code="CAISSE",
            libelle=f"Retrait épargne — compte #{compte_id}",
            agent_saisie=agent,
            lignes=[
                {"compte_numero": "521", "libelle_ligne": f"Épargne à vue — compte #{compte_id}", "debit": montant, "credit": 0},
                {"compte_numero": "530", "libelle_ligne": "Caisse — retrait épargne", "debit": 0, "credit": montant},
            ],
            db=db,
        )

    async def _create_ecriture(
        self,
        journal_code: str,
        libelle: str,
        agent_saisie: str,
        lignes: list[dict],
        db: Session,
    ):
        """Crée une écriture comptable avec ses lignes en base."""
        ecriture = Ecriture(
            date_comptable=datetime.utcnow(),
            journal_code=journal_code,
            libelle=libelle,
            agent_saisie=agent_saisie,
            statut="VALIDE",
            date_saisie=datetime.utcnow(),
        )
        db.add(ecriture)
        db.flush()  # Obtenir l'ID sans commit

        for ligne in lignes:
            db.add(LigneEcriture(ecriture_id=ecriture.id, **ligne))

        db.commit()
