# SIGMA Backend — Python FastAPI

API REST pour l'application SIGMA Micro-Finance.  
Déployée sur un PC serveur local (LAN), accessible par tous les postes Flutter du réseau.

---

## Stack technique

| Composant | Technologie |
|---|---|
| API REST | Python FastAPI |
| Base de données | PostgreSQL 15+ |
| ORM + Migrations | SQLAlchemy + Alembic |
| Authentification | JWT (python-jose) |
| Jobs planifiés | APScheduler |
| Mots de passe | passlib + bcrypt |
| Serveur ASGI | Uvicorn |

---

## Prérequis

- Python 3.11+
- PostgreSQL 15+
- pip

---

## Installation

### ✅ Installation automatique chez le client (recommandée)

Un script d'installation en un seul clic est disponible dans `install/`.

**Étapes pour le technicien :**

1. Placer ces fichiers dans `install/` avant livraison :
   - `python-3.11.9-amd64.exe` — https://www.python.org/downloads/
   - `postgresql-15-windows-x64.exe` — https://www.postgresql.org/download/windows/
   - `nssm.exe` (optionnel) — https://nssm.cc/

2. Sur le PC serveur du client :
   - Clic droit sur `install/install_serveur.bat`
   - **"Exécuter en tant qu'administrateur"**
   - Attendre ~5 minutes

Le script installe automatiquement Python, PostgreSQL, les dépendances, crée la base de données, lance les migrations et installe le service Windows (démarrage automatique).

**Identifiants créés par défaut :**
- Utilisateur : `admin` / Mot de passe : `Admin2024!`

---

### 🛠️ Installation manuelle (développeurs)

### 1. Prérequis
- Python 3.11+, PostgreSQL 15+

### 2. Environnement virtuel
```bash
python -m venv venv
venv\Scripts\activate        # Windows
source venv/bin/activate     # Linux/macOS
pip install -r requirements.txt
```

### 3. Configuration
```bash
cp .env.example .env
# Éditer .env avec vos paramètres PostgreSQL
```

### 4. Base de données
```sql
CREATE USER sigma_user WITH PASSWORD 'SigmaMF2024!';
CREATE DATABASE sigma_db OWNER sigma_user;
GRANT ALL PRIVILEGES ON DATABASE sigma_db TO sigma_user;
```

### 5. Migrations et démarrage
```bash
alembic upgrade head
python install/create_admin.py
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## Accès

| URL | Description |
|---|---|
| `http://[IP_SERVEUR]:8000` | API racine |
| `http://[IP_SERVEUR]:8000/docs` | Documentation Swagger interactive |
| `http://[IP_SERVEUR]:8000/redoc` | Documentation ReDoc |
| `http://[IP_SERVEUR]:8000/health` | Vérification d'état |

Remplacer `[IP_SERVEUR]` par l'adresse IP fixe du PC serveur sur le LAN (ex: `192.168.1.100`).

---

## Créer le premier utilisateur admin

Après démarrage, créer manuellement un admin via psql :

```sql
-- Remplacer le hash par le résultat de : python -c "from passlib.context import CryptContext; print(CryptContext(['bcrypt']).hash('votre_mot_de_passe'))"
INSERT INTO agents (id, first_name, last_name, role, is_active)
VALUES ('agent-admin-001', 'Admin', 'SIGMA', 'ADMIN', true);

INSERT INTO utilisateurs_systeme (id, agent_id, username, password_hash, role, is_active, created_at)
VALUES (
  'user-admin-001',
  'agent-admin-001',
  'admin',
  '$2b$12$REMPLACER_PAR_VOTRE_HASH',
  'ADMIN',
  true,
  NOW()
);
```

Ou via Python directement :

```python
from passlib.context import CryptContext
print(CryptContext(["bcrypt"]).hash("votre_mot_de_passe"))
```

---

## Structure du projet

```
backend/
├── main.py                  # Point d'entrée FastAPI
├── requirements.txt
├── .env.example
├── alembic.ini
├── alembic/
│   ├── env.py               # Configuration migrations
│   └── versions/            # Fichiers de migration générés
└── app/
    ├── core/
    │   ├── config.py         # Variables d'environnement
    │   ├── database.py       # Connexion PostgreSQL
    │   └── security.py       # JWT, bcrypt, dépendances auth
    ├── models/               # Modèles SQLAlchemy (tables)
    ├── schemas/              # Schémas Pydantic (validation)
    ├── routers/              # Routes API par module
    ├── services/
    │   ├── accounting_service.py   # Pont comptable automatique
    │   ├── penalty_service.py      # Calcul pénalités de retard
    │   └── scoring_service.py      # Score crédit dynamique
    └── jobs/
        ├── scheduler.py            # APScheduler
        ├── daily_penalties.py      # Job 00h05 — pénalités
        ├── monthly_interests.py    # Job 1er du mois — intérêts épargne
        └── nightly_scoring.py     # Job 02h00 — scores crédit
```

---

## Rôles utilisateurs

| Rôle | Accès |
|---|---|
| `ADMIN` | Tout, y compris configuration et gestion utilisateurs |
| `DIRECTEUR` | Tous les modules sauf configuration système |
| `CHEF_AGENCE` | Validation prêts, supervision agence |
| `CAISSIER` | Caisse, remboursements, épargne |
| `AGENT_TERRAIN` | Clients, prêts, collecte du jour |

---

## Jobs planifiés

| Job | Heure | Description |
|---|---|---|
| `daily_penalties` | 00h05 chaque jour | Calcule les pénalités sur échéances en retard |
| `monthly_interests` | 01h00 le 1er du mois | Capitalise les intérêts sur comptes épargne |
| `nightly_scoring` | 02h00 chaque jour | Recalcule les scores crédit clients |
