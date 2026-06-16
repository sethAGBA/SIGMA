from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user, require_roles, hash_password
from app.models.agent import Agent
from app.models.utilisateur import Utilisateur
from uuid import uuid4
from datetime import datetime

router = APIRouter(prefix="/agents", tags=["Agents"])


@router.get("")
def list_agents(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(Agent).filter(Agent.is_active == True).all()


@router.post("", status_code=status.HTTP_201_CREATED)
def create_agent(data: dict, db: Session = Depends(get_db), _=Depends(require_roles("ADMIN", "DIRECTEUR"))):
    agent = Agent(**{k: v for k, v in data.items() if k != "username" and k != "password"})
    db.add(agent)
    db.flush()

    # Créer le compte utilisateur si username/password fournis
    if data.get("username") and data.get("password"):
        user = Utilisateur(
            id=str(uuid4()),
            agent_id=agent.id,
            username=data["username"],
            password_hash=hash_password(data["password"]),
            role=data.get("role", "AGENT_TERRAIN"),
            created_at=datetime.utcnow(),
        )
        db.add(user)

    db.commit()
    db.refresh(agent)
    return agent


@router.get("/{agent_id}")
def get_agent(agent_id: str, db: Session = Depends(get_db), _=Depends(get_current_user)):
    agent = db.query(Agent).filter(Agent.id == agent_id).first()
    if not agent:
        raise HTTPException(status_code=404, detail="Agent introuvable")
    return agent
