from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey
from datetime import datetime
from app.core.database import Base


class Remboursement(Base):
    __tablename__ = "remboursements"

    id = Column(Integer, primary_key=True, autoincrement=True)
    pret_id = Column(Integer, ForeignKey("prets.id"), nullable=True)
    echeance_id = Column(Integer, ForeignKey("echeanciers.id"), nullable=True)
    montant_total = Column(Float, nullable=True)
    part_capital = Column(Float, nullable=True)
    part_interets = Column(Float, nullable=True)
    part_penalites = Column(Float, default=0.0)
    date_paiement = Column(DateTime, default=datetime.utcnow)
    mode_paiement = Column(String, nullable=True)
    numero_recu = Column(String, unique=True, nullable=False)
    agent_collecteur = Column(String, nullable=True)
    commentaire = Column(Text, nullable=True)


class ActionRecouvrement(Base):
    __tablename__ = "actions_recouvrement"

    id = Column(Integer, primary_key=True, autoincrement=True)
    pret_id = Column(Integer, ForeignKey("prets.id"), nullable=False)
    date_action = Column(DateTime, nullable=False, default=datetime.utcnow)
    type_action = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    agent_name = Column(String, nullable=True)
    resultat = Column(Text, nullable=True)
