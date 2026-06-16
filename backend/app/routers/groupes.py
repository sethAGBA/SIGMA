from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.groupe_solidaire import GroupeSolidaire

router = APIRouter(prefix="/groupes", tags=["Groupes Solidaires"])


@router.get("")
def list_groupes(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return db.query(GroupeSolidaire).order_by(GroupeSolidaire.date_creation.desc()).all()


@router.post("", status_code=status.HTTP_201_CREATED)
def create_groupe(data: dict, db: Session = Depends(get_db), _=Depends(get_current_user)):
    groupe = GroupeSolidaire(**data)
    db.add(groupe)
    db.commit()
    db.refresh(groupe)
    return groupe


@router.get("/{groupe_id}")
def get_groupe(groupe_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    groupe = db.query(GroupeSolidaire).filter(GroupeSolidaire.id == groupe_id).first()
    if not groupe:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    return groupe


@router.put("/{groupe_id}")
def update_groupe(groupe_id: int, data: dict, db: Session = Depends(get_db), _=Depends(get_current_user)):
    groupe = db.query(GroupeSolidaire).filter(GroupeSolidaire.id == groupe_id).first()
    if not groupe:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    for k, v in data.items():
        setattr(groupe, k, v)
    db.commit()
    return groupe
