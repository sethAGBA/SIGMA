from sqlalchemy import Column, String, Boolean, DateTime, Text
from datetime import datetime
from uuid import uuid4
from app.core.database import Base


class Utilisateur(Base):
    __tablename__ = "utilisateurs_systeme"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    agent_id = Column(String, nullable=False)
    username = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    # Rôles : ADMIN, DIRECTEUR, CHEF_AGENCE, CAISSIER, AGENT_TERRAIN
    role = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    permissions = Column(Text, nullable=True)
    last_login = Column(DateTime, nullable=True)
