"""Job quotidien — Calcul des pénalités de retard à 00h05."""
import logging
from app.core.database import SessionLocal
from app.services.penalty_service import PenaltyService

logger = logging.getLogger(__name__)


async def run_daily_penalties():
    """Calcule et applique les pénalités sur toutes les échéances en retard."""
    logger.info("Démarrage job : calcul pénalités de retard...")
    db = SessionLocal()
    try:
        result = await PenaltyService().calculate_and_apply_penalties(db)
        logger.info(f"Pénalités calculées : {result['echeances_traitees']} échéances, "
                    f"total = {result['total_penalites_calcule']} FCFA")
    except Exception as e:
        logger.error(f"Erreur job pénalités : {e}")
    finally:
        db.close()
