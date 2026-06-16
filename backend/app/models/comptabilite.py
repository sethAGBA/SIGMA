from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean, ForeignKey
from datetime import datetime
from app.core.database import Base


class CompteComptable(Base):
    __tablename__ = "comptes_comptables"

    id = Column(Integer, primary_key=True, autoincrement=True)
    numero = Column(String, unique=True, nullable=False, index=True)
    libelle = Column(String, nullable=False)
    classe = Column(Integer, nullable=False)
    type = Column(String, nullable=False)  # ACTIF, PASSIF, CHARGE, PRODUIT
    parent_account = Column(String, nullable=True)
    is_title = Column(Boolean, default=False)


class Journal(Base):
    __tablename__ = "journaux"

    id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String, unique=True, nullable=False)
    libelle = Column(String, nullable=False)


class Ecriture(Base):
    __tablename__ = "ecritures"

    id = Column(Integer, primary_key=True, autoincrement=True)
    date_comptable = Column(DateTime, nullable=False, default=datetime.utcnow)
    journal_code = Column(String, nullable=True)
    numero_piece = Column(String, nullable=True)
    libelle = Column(Text, nullable=True)
    agent_saisie = Column(String, nullable=True)
    statut = Column(String, default="BROUILLON")  # BROUILLON, VALIDE
    date_saisie = Column(DateTime, default=datetime.utcnow)
    piece_jointe = Column(String, nullable=True)


class LigneEcriture(Base):
    __tablename__ = "lignes_ecriture"

    id = Column(Integer, primary_key=True, autoincrement=True)
    ecriture_id = Column(Integer, ForeignKey("ecritures.id", ondelete="CASCADE"), nullable=True)
    compte_numero = Column(String, nullable=True)
    libelle_ligne = Column(Text, nullable=True)
    debit = Column(Float, default=0.0)
    credit = Column(Float, default=0.0)
    ref_externe = Column(String, nullable=True)
    tiers = Column(String, nullable=True)
    ref_analytique = Column(String, nullable=True)
