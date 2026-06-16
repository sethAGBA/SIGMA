"""
Script de création du compte administrateur initial.
Exécuté automatiquement pendant l'installation.
"""
import sys
import os

# Ajouter le dossier backend au path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from datetime import datetime
from uuid import uuid4

# Charger le .env
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env"))

from app.core.database import SessionLocal, create_tables
from app.core.security import hash_password
from app.models.agent import Agent
from app.models.utilisateur import Utilisateur


def create_admin():
    create_tables()
    db = SessionLocal()
    try:
        # Vérifier si l'admin existe déjà
        existing = db.query(Utilisateur).filter(Utilisateur.username == "admin").first()
        if existing:
            print("Compte admin déjà existant — aucune modification.")
            return

        # Créer l'agent associé
        agent = Agent(
            id="agent-admin-001",
            first_name="Administrateur",
            last_name="SIGMA",
            role="ADMIN",
            is_active=True,
        )
        db.merge(agent)
        db.flush()

        # Créer l'utilisateur admin
        user = Utilisateur(
            id=str(uuid4()),
            agent_id="agent-admin-001",
            username="admin",
            password_hash=hash_password("Admin2024!"),
            role="ADMIN",
            is_active=True,
            created_at=datetime.utcnow(),
        )
        db.add(user)
        db.commit()
        print("Compte admin créé avec succès (admin / Admin2024!)")

    except Exception as e:
        db.rollback()
        print(f"Erreur création admin : {e}")
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    create_admin()
