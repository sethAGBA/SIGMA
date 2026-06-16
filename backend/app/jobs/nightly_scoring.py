"""Job nocturne — Recalcul des scores de crédit à 02h00."""
import logging
from app.core.database import SessionLocal
from app.services.scoring_service import ScoringService

logger = logging.getLogger(__name__)


async def run_nightly_scoring():
    """Recalcule le score crédit de tous les clients actifs."""
    logger.info("Démarrage job : recalcul scores crédit...")
    db = SessionLocal()
    try:
        result = await ScoringService().recalculate_all_scores(db)
        logger.info(f"Scores recalculés : {result['clients_traites']} clients traités")
    except Exception as e:
        logger.error(f"Erreur job scoring : {e}")
    finally:
        db.close()
