from sqlalchemy import Column, Integer, String, Float, DateTime, Text
from datetime import datetime
from app.core.database import Base


class OperationCaisse(Base):
    __tablename__ = "operations_caisse"

    id = Column(Integer, primary_key=True, autoincrement=True)
    agence_id = Column(String, nullable=True)
    type_operation = Column(String, nullable=True)  # ENTREE, SORTIE
    categorie = Column(String, nullable=True)
    montant = Column(Float, nullable=True)
    devise = Column(String, default="FCFA")
    mode_paiement = Column(String, nullable=True)
    libelle = Column(String, nullable=True)
    reference_externe = Column(String, nullable=True)
    agent_operation = Column(String, nullable=True)
    date_operation = Column(DateTime, default=datetime.utcnow)


class ClotureCaisse(Base):
    __tablename__ = "clotures_caisse"

    id = Column(Integer, primary_key=True, autoincrement=True)
    date_cloture = Column(DateTime, nullable=False, default=datetime.utcnow)
    agent_cloture = Column(String, nullable=False)
    solde_initial = Column(Float, nullable=True)
    total_entrees = Column(Float, nullable=True)
    total_sorties = Column(Float, nullable=True)
    solde_theorique = Column(Float, nullable=True)
    solde_physique = Column(Float, nullable=True)
    ecart = Column(Float, nullable=True)
    observations = Column(Text, nullable=True)
    billetage = Column(Text, nullable=True)  # JSON des coupures physiques
