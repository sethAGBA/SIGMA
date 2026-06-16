from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class LigneEcritureCreate(BaseModel):
    compte_numero: str
    libelle_ligne: Optional[str] = None
    debit: float = 0.0
    credit: float = 0.0
    tiers: Optional[str] = None
    ref_analytique: Optional[str] = None


class EcritureCreate(BaseModel):
    date_comptable: datetime
    journal_code: str
    numero_piece: Optional[str] = None
    libelle: Optional[str] = None
    agent_saisie: Optional[str] = None
    lignes: List[LigneEcritureCreate]


class EcritureResponse(BaseModel):
    id: int
    date_comptable: datetime
    journal_code: Optional[str] = None
    numero_piece: Optional[str] = None
    libelle: Optional[str] = None
    statut: Optional[str] = None

    model_config = {"from_attributes": True}
