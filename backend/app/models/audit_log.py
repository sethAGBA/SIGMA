from sqlalchemy import Column, String, DateTime, Text
from datetime import datetime
from uuid import uuid4
from app.core.database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, nullable=True)
    username = Column(String, nullable=True)
    action = Column(String, nullable=False)
    details = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    severity = Column(String, nullable=False, default="INFO")  # INFO, WARNING, CRITICAL
    ip_address = Column(String, nullable=True)
