from sqlalchemy import Column, String, Float, Boolean, DateTime
from datetime import datetime
from uuid import uuid4
from app.core.database import Base


class Agency(Base):
    __tablename__ = "agencies"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    name = Column(String, nullable=False)
    code = Column(String, nullable=False, unique=True)
    address = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    email = Column(String, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    coverage_area = Column(String, nullable=True)
    opening_date = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)
