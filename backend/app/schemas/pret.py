from pydantic import BaseModel
from typing import Optional
from datetime import datetime


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
    agent_collecteur: Optional[str] = None
    commentaire: Optional[str] = None
