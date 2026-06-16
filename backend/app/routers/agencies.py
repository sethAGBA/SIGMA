from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.agency import Agency

router = APIRouter(prefix="/agencies", tags=["Agences"])


@router.get("")
def list_agencies(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(Agency).filter(Agency.is_active == True).all()


@router.post("", status_code=status.HTTP_201_CREATED)
def create_agency(data: dict, db: Session = Depends(get_db), _=Depends(get_current_user)):
    agency = Agency(**data)
    db.add(agency)
    db.commit()
    db.refresh(agency)
    return agency


@router.get("/{agency_id}")
def get_agency(agency_id: str, db: Session = Depends(get_db), _=Depends(get_current_user)):
    agency = db.query(Agency).filter(Agency.id == agency_id).first()
    if not agency:
        raise HTTPException(status_code=404, detail="Agence introuvable")
    return agency
