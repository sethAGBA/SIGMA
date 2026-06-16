from sqlalchemy import Column, String, Boolean, DateTime
from datetime import datetime
from uuid import uuid4
from app.core.database import Base


class Agent(Base):
    __tablename__ = "agents"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    email = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    role = Column(String, nullable=False)
    agency_id = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    photo_url = Column(String, nullable=True)
    hired_date = Column(DateTime, nullable=True)
    associated_account_id = Column(String, nullable=True)
