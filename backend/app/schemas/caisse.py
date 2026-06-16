from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class OperationCaisseCreate(BaseModel):
    agence_id: Optional[str] = None
    type_operation: str  # ENTREE, SORTIE
    categorie: Optional[str] = None
    montant: float
    mode_paiement: Optional[str] = None
    libelle: Optional[str] = None
    reference_externe: Optional[str] = None
    agent_operation: Optional[str] = None


class OperationCaisseResponse(OperationCaisseCreate):
    id: int
    date_operation: Optional[datetime] = None

    model_config = {"from_attributes": True}


class ClotureCaisseCreate(BaseModel):
    agent_cloture: str
    solde_physique: float
    observations: Optional[str] = None
    billetage: Optional[str] = None  # JSON stringifié des coupures


class ClotureCaisseResponse(BaseModel):
    id: int
    date_cloture: datetime
    agent_cloture: str
    solde_theorique: Optional[float] = None
    solde_physique: Optional[float] = None
    ecart: Optional[float] = None

    model_config = {"from_attributes": True}
