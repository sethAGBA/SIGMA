from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from app.core.database import get_db
from app.core.security import (
    verify_password, create_access_token, create_refresh_token,
    decode_token, get_current_user, hash_password,
)
from app.models.utilisateur import Utilisateur
from app.models.audit_log import AuditLog
from app.schemas.auth import LoginRequest, TokenResponse, UserInfo, RefreshRequest

router = APIRouter(prefix="/auth", tags=["Authentification"])


@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """Authentification — retourne un token JWT d'accès et un refresh token."""
    user = db.query(Utilisateur).filter(
        Utilisateur.username == request.username,
        Utilisateur.is_active == True,
    ).first()

    if not user or not verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants incorrects",
        )

    # Mettre à jour la date de dernière connexion
    user.last_login = datetime.utcnow()
    db.commit()

    # Journaliser la connexion
    log = AuditLog(
        user_id=user.id,
        username=user.username,
        action="LOGIN",
        details=f"Connexion réussie — rôle: {user.role}",
        severity="INFO",
    )
    db.add(log)
    db.commit()

    token_data = {"sub": user.id, "username": user.username, "role": user.role}
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserInfo(
            id=user.id,
            username=user.username,
            role=user.role,
            agent_id=user.agent_id,
        ),
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(request: RefreshRequest, db: Session = Depends(get_db)):
    """Renouvelle le token d'accès à partir du refresh token."""
    payload = decode_token(request.refresh_token)

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de rafraîchissement invalide",
        )

    user_id = payload.get("sub")
    user = db.query(Utilisateur).filter(
        Utilisateur.id == user_id,
        Utilisateur.is_active == True,
    ).first()

    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Utilisateur introuvable")

    token_data = {"sub": user.id, "username": user.username, "role": user.role}
    return TokenResponse(
        access_token=create_access_token(data=token_data),
        refresh_token=create_refresh_token(data=token_data),
        user=UserInfo(id=user.id, username=user.username, role=user.role, agent_id=user.agent_id),
    )


@router.post("/logout")
def logout(current_user: Utilisateur = Depends(get_current_user), db: Session = Depends(get_db)):
    """Déconnexion — journalise l'action."""
    log = AuditLog(
        user_id=current_user.id,
        username=current_user.username,
        action="LOGOUT",
        details="Déconnexion",
        severity="INFO",
    )
    db.add(log)
    db.commit()
    return {"message": "Déconnexion réussie"}


@router.get("/me", response_model=UserInfo)
def get_me(current_user: Utilisateur = Depends(get_current_user)):
    """Retourne l'utilisateur actuellement connecté."""
    return UserInfo(
        id=current_user.id,
        username=current_user.username,
        role=current_user.role,
        agent_id=current_user.agent_id,
    )
