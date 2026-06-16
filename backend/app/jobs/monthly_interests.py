"""Job mensuel — Capitalisation des intérêts sur épargne le 1er du mois à 01h00."""
import logging
from datetime import datetime
from app.core.database import SessionLocal
from app.models.epargne import CompteEpargne, TransactionEpargne
from app.models.produit_financier import ProduitFinancier

logger = logging.getLogger(__name__)


async def run_monthly_interests():
    """
    Capitalise les intérêts sur tous les comptes d'épargne actifs.
    Formule : intérêts = solde * (taux_annuel / 100 / 12)
    Génère une transaction de type INTERETS et met à jour le solde + interets_acquis.
    """
    logger.info("Démarrage job : capitalisation intérêts épargne...")
    db = SessionLocal()
    try:
        comptes = db.query(CompteEpargne).filter(CompteEpargne.statut == "Actif").all()
        count = 0
        total_interets = 0.0

        for compte in comptes:
            taux = compte.taux_interet_applique or 0.0
            if taux <= 0 or compte.solde <= 0:
                continue

            interets = round(compte.solde * (taux / 100 / 12), 0)
            if interets <= 0:
                continue

            # Créditer les intérêts sur le compte
            compte.solde += interets
            compte.interets_acquis = (compte.interets_acquis or 0) + interets

            # Journaliser la transaction
            transaction = TransactionEpargne(
                compte_id=compte.id,
                type_operation="INTERETS",
                montant=interets,
                solde_apres=compte.solde,
                agent_operation="SYSTÈME",
                commentaire=f"Intérêts mensuels — {datetime.utcnow().strftime('%B %Y')}",
            )
            db.add(transaction)

            # Écriture comptable : Débit 602 / Crédit 521
            from app.services.accounting_service import AutomaticAccountingService
            # Note : on ne peut pas awaiter ici facilement, appel direct
            from app.models.comptabilite import Ecriture, LigneEcriture
            ecriture = Ecriture(
                date_comptable=datetime.utcnow(),
                journal_code="OD",
                libelle=f"Intérêts épargne compte #{compte.id} — {datetime.utcnow().strftime('%B %Y')}",
                agent_saisie="SYSTÈME",
                statut="VALIDE",
                date_saisie=datetime.utcnow(),
            )
            db.add(ecriture)
            db.flush()
            db.add(LigneEcriture(ecriture_id=ecriture.id, compte_numero="602", libelle_ligne="Intérêts sur épargne", debit=interets, credit=0))
            db.add(LigneEcriture(ecriture_id=ecriture.id, compte_numero="521", libelle_ligne=f"Épargne compte #{compte.id}", debit=0, credit=interets))

            total_interets += interets
            count += 1

        db.commit()
        logger.info(f"Intérêts capitalisés : {count} comptes, total = {total_interets} FCFA")
    except Exception as e:
        db.rollback()
        logger.error(f"Erreur job intérêts : {e}")
    finally:
        db.close()
