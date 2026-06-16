from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Boolean
from datetime import datetime
from app.core.database import Base


class DemandePret(Base):
    __tablename__ = "demandes_pret"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=True)
    produit_id = Column(Integer, ForeignKey("produits_financiers.id"), nullable=True)
    montant_demande = Column(Float, nullable=True)
    duree_mois = Column(Integer, nullable=True)
    frequence_remboursement = Column(String, nullable=True)
    objet_pret = Column(Text, nullable=True)
    mensualite = Column(Float, nullable=True)
    total_a_rembourser = Column(Float, nullable=True)
    cout_total_credit = Column(Float, nullable=True)
    teg = Column(Float, nullable=True)
    revenus_mensuels = Column(Float, nullable=True)
    charges_mensuelles = Column(Float, nullable=True)
    capacite_remboursement = Column(Float, nullable=True)
    taux_effort = Column(Float, nullable=True)
    autres_dettes = Column(Float, nullable=True)
    reste_a_vivre = Column(Float, nullable=True)
    type_garantie = Column(String, nullable=True)
    description_garantie = Column(Text, nullable=True)
    valeur_garantie = Column(Float, nullable=True)
    caution_personnelle = Column(Text, nullable=True)
    rapport_visite = Column(Text, nullable=True)
    observations_visite = Column(Text, nullable=True)
    photos_visite = Column(Text, nullable=True)
    score_calcule = Column(Integer, nullable=True)
    recommandation_systeme = Column(Text, nullable=True)
    avis_agent = Column(Text, nullable=True)
    avis_chef_agence = Column(Text, nullable=True)
    avis_comite = Column(Text, nullable=True)
    documents_dossier = Column(Text, nullable=True)
    statut = Column(String, nullable=True)
    date_creation = Column(DateTime, default=datetime.utcnow)
    date_modification = Column(DateTime, onupdate=datetime.utcnow)
    motif_rejet = Column(Text, nullable=True)


class Pret(Base):
    __tablename__ = "prets"

    id = Column(Integer, primary_key=True, autoincrement=True)
    demande_pret_id = Column(Integer, ForeignKey("demandes_pret.id"), nullable=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=True)
    produit_id = Column(Integer, ForeignKey("produits_financiers.id"), nullable=True)
    numero_pret = Column(String, unique=True, nullable=False, index=True)
    montant_initial = Column(Float, nullable=True)
    solde_restant = Column(Float, nullable=True)
    date_deblocage = Column(DateTime, nullable=True)
    date_echeance_prochaine = Column(DateTime, nullable=True)
    jours_retard = Column(Integer, default=0)
    statut = Column(String, nullable=True)
    agent_gestionnaire = Column(String, nullable=True)
    agence_gestion = Column(String, nullable=True)


class Echeancier(Base):
    __tablename__ = "echeanciers"

    id = Column(Integer, primary_key=True, autoincrement=True)
    pret_id = Column(Integer, ForeignKey("prets.id", ondelete="CASCADE"), nullable=False)
    numero_echeance = Column(Integer, nullable=False)
    date_prevue = Column(DateTime, nullable=True)
    capital_du = Column(Float, nullable=True)
    interets_dus = Column(Float, nullable=True)
    frais_dus = Column(Float, default=0.0)
    total_du = Column(Float, nullable=True)
    capital_paye = Column(Float, default=0.0)
    interets_payes = Column(Float, default=0.0)
    frais_payes = Column(Float, default=0.0)
    total_paye = Column(Float, default=0.0)
    capital_restant = Column(Float, nullable=True)
    statut = Column(String, nullable=True)
    date_effectuee = Column(DateTime, nullable=True)


class Garantie(Base):
    __tablename__ = "garanties"

    id = Column(Integer, primary_key=True, autoincrement=True)
    pret_id = Column(Integer, ForeignKey("prets.id", ondelete="CASCADE"), nullable=True)
    type = Column(String, nullable=False)
    valeur_estimee = Column(Float, nullable=True)
    description = Column(Text, nullable=True)
    date_creation = Column(DateTime, default=datetime.utcnow)
