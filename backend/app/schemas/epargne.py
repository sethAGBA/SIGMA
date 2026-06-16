from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class CompteEpargneCreate(BaseModel):
    client_id: int
    produit_id: int
    numero_compte: str
    taux_interet_applique: Optional[float] = None
    statut: Optional[str] = "Actif"


class CompteEpargneResponse(BaseModel):
    id: int
    client_id: Optional[int] = None
    produit_id: Optional[int] = None
    numero_compte: str
    solde: float = 0.0
    interets_acquis: float = 0.0
    statut: Optional[str] = None
    date_ouverture: Optional[datetime] = None

    model_config = {"from_attributes": True}


class TransactionCreate(BaseModel):
    compte_id: int
    type_operation: str  # DEPOT, RETRAIT
    montant: float
    agent_operation: Optional[str] = None
    commentaire: Optional[str] = None
