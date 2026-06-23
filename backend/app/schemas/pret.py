from pydantic import BaseModel
from typing import Optional
from datetime import datetime


# ---------------------------------------------------------------------------
# Schémas Demandes de prêt (Phase 3)
# ---------------------------------------------------------------------------

class LoanRequestCreate(BaseModel):
    """Payload pour POST /demandes-pret — correspond aux champs de LoanRequest.toMap() Flutter."""

    # Champs obligatoires
    client_id: int
    produit_id: int
    montant_demande: float
    duree_mois: int
    frequence_remboursement: str
    objet_pret: str
    mensualite: float
    total_a_rembourser: float
    cout_total_credit: float
    teg: float

    # Différé capital
    mois_differe_capital: Optional[int] = 0

    # Analyse financière
    revenus_mensuels: Optional[float] = 0.0
    charges_mensuelles: Optional[float] = 0.0
    capacite_remboursement: Optional[float] = 0.0
    taux_effort: Optional[float] = 0.0
    autres_dettes: Optional[float] = 0.0
    reste_a_vivre: Optional[float] = 0.0

    # Garanties
    type_garantie: Optional[str] = None
    description_garantie: Optional[str] = None
    valeur_garantie: Optional[float] = None
    caution_personnelle: Optional[str] = None

    # Visite terrain
    rapport_visite: Optional[str] = None
    observations_visite: Optional[str] = None
    photos_visite: Optional[str] = None  # chemins séparés par virgule
    latitude_visite: Optional[float] = None
    longitude_visite: Optional[float] = None

    # Scoring
    score_calcule: Optional[int] = 0
    recommandation_systeme: Optional[str] = None

    # Circuit de décision
    avis_agent: Optional[str] = None
    avis_chef_agence: Optional[str] = None
    avis_comite: Optional[str] = None

    # Documents joints (chemins séparés par virgule)
    documents_dossier: Optional[str] = None

    # Statut initial
    statut: Optional[str] = "brouillon"

    # Dates
    date_creation: Optional[datetime] = None
    date_modification: Optional[datetime] = None


class LoanRequestStatusUpdate(BaseModel):
    """Payload pour PUT /demandes-pret/{id}/statut."""

    statut: str
    motif_rejet: Optional[str] = None


class DisburseRequest(BaseModel):
    """Payload pour POST /demandes-pret/{id}/debloquer — correspond à Loan.toMap() Flutter."""

    # Identifiants locaux créés côté Flutter avant synchronisation
    loan_id: Optional[int] = None          # ID SQLite local (pour idempotence sync)
    request_id: Optional[int] = None       # ID de la demande (redondant avec l'URL, utile pour la queue)

    # Données du prêt créé
    client_id: Optional[int] = None
    produit_id: Optional[int] = None
    numero_pret: Optional[str] = None
    montant_initial: Optional[float] = None
    solde_restant: Optional[float] = None
    date_deblocage: Optional[datetime] = None
    date_echeance_prochaine: Optional[datetime] = None
    jours_retard: Optional[int] = 0
    statut: Optional[str] = None
    agent_gestionnaire: Optional[str] = None
    agence_gestion: Optional[str] = None
    mois_differe_capital: Optional[int] = 0


class DemandePretResponse(BaseModel):
    """Réponse pour GET /demandes-pret et POST /demandes-pret."""

    id: int
    client_id: Optional[int] = None
    produit_id: Optional[int] = None
    montant_demande: Optional[float] = None
    duree_mois: Optional[int] = None
    frequence_remboursement: Optional[str] = None
    objet_pret: Optional[str] = None
    mensualite: Optional[float] = None
    total_a_rembourser: Optional[float] = None
    cout_total_credit: Optional[float] = None
    teg: Optional[float] = None
    statut: Optional[str] = None
    date_creation: Optional[datetime] = None
    date_modification: Optional[datetime] = None
    motif_rejet: Optional[str] = None

    # Champs analyse financière
    revenus_mensuels: Optional[float] = None
    charges_mensuelles: Optional[float] = None
    capacite_remboursement: Optional[float] = None
    taux_effort: Optional[float] = None
    autres_dettes: Optional[float] = None
    reste_a_vivre: Optional[float] = None

    # Garanties
    type_garantie: Optional[str] = None
    description_garantie: Optional[str] = None
    valeur_garantie: Optional[float] = None
    caution_personnelle: Optional[str] = None

    # Scoring
    score_calcule: Optional[int] = None
    recommandation_systeme: Optional[str] = None

    # Circuit de décision
    avis_agent: Optional[str] = None
    avis_chef_agence: Optional[str] = None
    avis_comite: Optional[str] = None

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Schémas Prêts (existants)
# ---------------------------------------------------------------------------

class PretBase(BaseModel):
    client_id: int
    produit_id: int
    numero_pret: str
    montant_initial: float
    statut: Optional[str] = "En cours"
    agent_gestionnaire: Optional[str] = None
    agence_gestion: Optional[str] = None


class PretCreate(PretBase):
    demande_pret_id: Optional[int] = None
    date_deblocage: Optional[datetime] = None


class PretResponse(PretBase):
    id: int
    solde_restant: Optional[float] = None
    jours_retard: Optional[int] = 0
    date_deblocage: Optional[datetime] = None
    date_echeance_prochaine: Optional[datetime] = None

    model_config = {"from_attributes": True}


class EcheancierResponse(BaseModel):
    id: int
    pret_id: int
    numero_echeance: int
    date_prevue: Optional[datetime] = None
    capital_du: Optional[float] = None
    interets_dus: Optional[float] = None
    total_du: Optional[float] = None
    total_paye: Optional[float] = 0.0
    statut: Optional[str] = None

    model_config = {"from_attributes": True}


class RemboursementCreate(BaseModel):
    pret_id: int
    echeance_id: Optional[int] = None
    montant_total: float
    part_capital: float
    part_interets: float
    part_penalites: Optional[float] = 0.0
    mode_paiement: str
    numero_recu: Optional[str] = None
    agent_collecteur: Optional[str] = None
    commentaire: Optional[str] = None


class LoanRequestCreate(BaseModel):
    client_id: int
    produit_id: Optional[int] = None
    montant_demande: float
    duree_mois: int
    frequence_remboursement: str
    objet_pret: str
    mensualite: float
    total_a_rembourser: float
    cout_total_credit: Optional[float] = None
    teg: Optional[float] = None
    revenus_mensuels: Optional[float] = None
    charges_mensuelles: Optional[float] = None
    capacite_remboursement: Optional[float] = None
    taux_effort: Optional[float] = None
    autres_dettes: Optional[float] = None
    reste_a_vivre: Optional[float] = None
    type_garantie: Optional[str] = None
    description_garantie: Optional[str] = None
    valeur_garantie: Optional[float] = None
    caution_personnelle: Optional[str] = None
    rapport_visite: Optional[str] = None
    observations_visite: Optional[str] = None
    photos_visite: Optional[str] = None
    score_calcule: Optional[int] = None
    recommandation_systeme: Optional[str] = None
    avis_agent: Optional[str] = None
    statut: Optional[str] = "En attente"


class LoanRequestStatusUpdate(BaseModel):
    statut: str
    motif_rejet: Optional[str] = None


class EcheancierCreate(BaseModel):
    numero_echeance: int
    date_prevue: Optional[datetime] = None
    capital_du: Optional[float] = None
    interets_dus: Optional[float] = None
    frais_dus: Optional[float] = 0.0
    total_du: Optional[float] = None
    capital_restant: Optional[float] = None
    statut: Optional[str] = "En attente"


class DisburseRequest(BaseModel):
    montant_initial: float
    taux_interet: Optional[float] = None
    duree_mois: int
    date_deblocage: Optional[datetime] = None
    agent_gestionnaire: Optional[str] = None
    agence_gestion: Optional[str] = None
    echeancier: Optional[list[EcheancierCreate]] = None
