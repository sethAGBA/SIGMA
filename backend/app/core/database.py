from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Dépendance FastAPI — fournit une session DB et la ferme après la requête."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables():
    """Crée toutes les tables définies dans les modèles SQLAlchemy."""
    # Import des modèles pour que SQLAlchemy les découvre
    from app.models import (  # noqa: F401
        utilisateur, agent, agency, client, groupe_solidaire,
        produit_financier, pret, epargne, caisse, comptabilite, audit_log,
    )
    Base.metadata.create_all(bind=engine)
