from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user, require_roles

router = APIRouter(prefix="/configuration", tags=["Configuration"])


@router.get("")
def get_configuration(db: Session = Depends(get_db), _=Depends(get_current_user)):
    """Retourne les paramètres de l'institution."""
    from sqlalchemy import text
    try:
        rows = db.execute(text("SELECT key, value FROM configurations")).fetchall()
        return {row.key: row.value for row in rows}
    except Exception:
        return {}


@router.put("")
def update_configuration(
    data: dict,
    db: Session = Depends(get_db),
    _=Depends(require_roles("ADMIN")),
):
    """Met à jour les paramètres (ADMIN uniquement)."""
    from sqlalchemy import text
    for key, value in data.items():
        db.execute(
            text("INSERT INTO configurations (key, value) VALUES (:k, :v) ON CONFLICT (key) DO UPDATE SET value = :v"),
            {"k": key, "v": str(value)},
        )
    db.commit()
    return {"message": "Configuration mise à jour"}
