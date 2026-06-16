from sqlalchemy import Column, Integer, String, Float, Boolean, Text
from app.core.database import Base


class ProduitFinancier(Base):
    __tablename__ = "produits_financiers"

    id = Column(Integer, primary_key=True, autoincrement=True)
    nom = Column(String, nullable=False)
    code = Column(String, unique=True, nullable=False)
    description = Column(Text, nullable=True)
    type = Column(String, nullable=False)  # credit, epargne
    taux_interet = Column(Float, nullable=True)
    credit_category = Column(String, nullable=True)
    montant_min = Column(Float, nullable=True)
    montant_max = Column(Float, nullable=True)
    duree_min_mois = Column(Integer, nullable=True)
    duree_max_mois = Column(Integer, nullable=True)
    mode_calcul_interet = Column(String, nullable=True)
    frequence_remboursement = Column(String, nullable=True)
    conditions_eligibilite = Column(Text, nullable=True)
    documents_requis = Column(Text, nullable=True)
    frais_commissions = Column(Text, nullable=True)
    assurances_obligatoires = Column(Text, nullable=True)
    differe_possible = Column(Boolean, default=False)
    secteurs_eligibles = Column(Text, nullable=True)
    materiel_financable = Column(Text, nullable=True)
    accompagnement_technique = Column(Text, nullable=True)
    garantie_sur_equipement = Column(Text, nullable=True)
    procedure_acceleree = Column(Boolean, default=False)
    caution_solidaire_requise = Column(Boolean, default=False)
    savings_category = Column(String, nullable=True)
    solde_minimum = Column(Float, nullable=True)
    versement_minimum = Column(Float, nullable=True)
