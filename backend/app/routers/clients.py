from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.client import Client
from app.schemas.client import ClientCreate, ClientUpdate, ClientResponse, ClientListResponse

router = APIRouter(prefix="/clients", tags=["Clients"])


@router.get("", response_model=ClientListResponse)
def list_clients(
    search: Optional[str] = Query(None, description="Recherche par nom, téléphone, numéro"),
    status: Optional[str] = Query(None, description="Actif | Inactif | Blacklisté"),
    risk_level: Optional[str] = Query(None, description="Faible | Moyen | Élevé"),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(Client)

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (Client.nom.ilike(pattern)) |
            (Client.prenoms.ilike(pattern)) |
            (Client.telephone.ilike(pattern)) |
            (Client.numero_client.ilike(pattern))
        )
    if status:
        query = query.filter(Client.statut == status)
    if risk_level:
        query = query.filter(Client.niveau_risque == risk_level)

    total = query.count()
    items = query.order_by(Client.date_creation.desc()).offset((page - 1) * limit).limit(limit).all()

    return ClientListResponse(items=items, total=total, page=page, limit=limit)


@router.post("", response_model=ClientResponse, status_code=status.HTTP_201_CREATED)
def create_client(data: ClientCreate, db: Session = Depends(get_db), _=Depends(get_current_user)):
    # Vérifier les doublons
    existing = db.query(Client).filter(Client.numero_client == data.numero_client).first()
    if existing:
        raise HTTPException(status_code=400, detail="Numéro client déjà utilisé")

    client = Client(**data.model_dump())
    db.add(client)
    db.commit()
    db.refresh(client)
    return client


@router.get("/{client_id}", response_model=ClientResponse)
def get_client(client_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    client = db.query(Client).filter(Client.id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client introuvable")
    return client


@router.put("/{client_id}", response_model=ClientResponse)
def update_client(
    client_id: int,
    data: ClientUpdate,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    client = db.query(Client).filter(Client.id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client introuvable")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(client, field, value)

    db.commit()
    db.refresh(client)
    return client


@router.delete("/{client_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_client(client_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    client = db.query(Client).filter(Client.id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client introuvable")
    db.delete(client)
    db.commit()
