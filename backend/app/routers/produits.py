from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.produit_financier import ProduitFinancier

router = APIRouter(prefix="/produits", tags=["Produits Financiers"])


@router.get("")
def list_produits(
    type: Optional[str] = Query(None, description="credit | epargne"),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(ProduitFinancier)
    if type:
        query = query.filter(ProduitFinancier.type == type)
    return query.all()


@router.post("", status_code=status.HTTP_201_CREATED)
def create_produit(data: dict, db: Session = Depends(get_db), _=Depends(get_current_user)):
    produit = ProduitFinancier(**data)
    db.add(produit)
    db.commit()
    db.refresh(produit)
    return produit


@router.get("/{produit_id}")
def get_produit(produit_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    p = db.query(ProduitFinancier).filter(ProduitFinancier.id == produit_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    return p


@router.put("/{produit_id}")
def update_produit(produit_id: int, data: dict, db: Session = Depends(get_db), _=Depends(get_current_user)):
    p = db.query(ProduitFinancier).filter(ProduitFinancier.id == produit_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    for k, v in data.items():
        setattr(p, k, v)
    db.commit()
    return p


@router.delete("/{produit_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_produit(produit_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    p = db.query(ProduitFinancier).filter(ProduitFinancier.id == produit_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    db.delete(p)
    db.commit()
