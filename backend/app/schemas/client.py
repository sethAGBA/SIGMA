from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ClientBase(BaseModel):
    nom: str
    prenoms: str
    telephone: Optional[str] = None
    email: Optional[str] = None
    adresse: Optional[str] = None
    activite_principale: Optional[str] = None
    revenus_mensuels: Optional[float] = None
    charges_mensuelles: Optional[float] = None
    score_credit: Optional[int] = 50
    niveau_risque: Optional[str] = "Moyen"
    statut: Optional[str] = "Actif"
    agence: Optional[str] = None
    agent_affecte: Optional[str] = None


class ClientCreate(ClientBase):
    numero_client: str


class ClientUpdate(ClientBase):
    pass


class ClientResponse(ClientBase):
    id: int
    numero_client: str
    date_creation: Optional[datetime] = None

    model_config = {"from_attributes": True}


class ClientListResponse(BaseModel):
    items: list[ClientResponse]
    total: int
    page: int
    limit: int
