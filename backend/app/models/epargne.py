from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey
from datetime import datetime
from app.core.database import Base


class CompteEpargne(Base):
    __tablename__ = "comptes_epargne"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=True)
    produit_id = Column(Integer, ForeignKey("produits_financiers.id"), nullable=True)
    numero_compte = Column(String, unique=True, nullable=False, index=True)
    solde = Column(Float, default=0.0)
    interets_acquis = Column(Float, default=0.0)
    statut = Column(String, nullable=True)  # Actif, Bloqué, Fermé
    date_ouverture = Column(DateTime, default=datetime.utcnow)
    taux_interet_applique = Column(Float, nullable=True)


class TransactionEpargne(Base):
    __tablename__ = "transactions_epargne"

    id = Column(Integer, primary_key=True, autoincrement=True)
    compte_id = Column(Integer, ForeignKey("comptes_epargne.id"), nullable=True)
    type_operation = Column(String, nullable=True)  # DEPOT, RETRAIT, INTERETS
    montant = Column(Float, nullable=True)
    solde_apres = Column(Float, nullable=True)
    agent_operation = Column(String, nullable=True)
    date_operation = Column(DateTime, default=datetime.utcnow)
    numero_piece = Column(String, nullable=True)
    commentaire = Column(Text, nullable=True)
