from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey
from datetime import datetime
from app.core.database import Base


class GroupeSolidaire(Base):
    __tablename__ = "groupes_solidaires"

    id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String, unique=True, nullable=False)
    nom = Column(String, nullable=False)
    responsable_id = Column(Integer, ForeignKey("clients.id"), nullable=True)
    tresorier_id = Column(Integer, ForeignKey("clients.id"), nullable=True)
    date_creation = Column(DateTime, default=datetime.utcnow)
    statut = Column(String, default="Actif")  # Actif, Inactif, Dissous
    description = Column(Text, nullable=True)
