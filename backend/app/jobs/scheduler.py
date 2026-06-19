# Phase 3 OK
"""
Scheduler APScheduler — Jobs planifiés SIGMA.

- 00h05 : Calcul pénalités de retard (daily_penalties)
- 01h00 le 1er du mois : Capitalisation intérêts épargne (monthly_interests)
- 02h00 : Recalcul scores crédit (nightly_scoring)
"""
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import logging

logger = logging.getLogger(__name__)
scheduler = AsyncIOScheduler()


def start_scheduler():
    """Démarre le scheduler avec tous les jobs planifiés."""
    from app.jobs.daily_penalties import run_daily_penalties
    from app.jobs.monthly_interests import run_monthly_interests
    from app.jobs.nightly_scoring import run_nightly_scoring

    # Job quotidien à 00h05 — calcul des pénalités
    scheduler.add_job(
        run_daily_penalties,
        CronTrigger(hour=0, minute=5),
        id="daily_penalties",
        name="Calcul pénalités de retard",
        replace_existing=True,
    )

    # Job mensuel le 1er à 01h00 — capitalisation des intérêts épargne
    scheduler.add_job(
        run_monthly_interests,
        CronTrigger(day=1, hour=1, minute=0),
        id="monthly_interests",
        name="Capitalisation intérêts épargne",
        replace_existing=True,
    )

    # Job nocturne à 02h00 — recalcul scores crédit
    scheduler.add_job(
        run_nightly_scoring,
        CronTrigger(hour=2, minute=0),
        id="nightly_scoring",
        name="Recalcul scores crédit",
        replace_existing=True,
    )

    scheduler.start()
    logger.info("Scheduler APScheduler démarré — 3 jobs planifiés")
