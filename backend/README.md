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

## Architecture des bases de données

Le projet utilise **deux bases de données distinctes** qui coexistent pendant la phase de transition :

| Base | Nom | Type | Où | Rôle |
|---|---|---|---|---|
| **SQLite locale** | `sigma_microfinance.db` | SQLite | PC de chaque utilisateur (dossier Documents) | App Flutter actuelle — mode offline permanent |
| **PostgreSQL réseau** | `sigma_db` | PostgreSQL | PC serveur uniquement | Backend FastAPI — mode réseau LAN |

> **Important** : `sigma_microfinance.db` est le fichier SQLite créé automatiquement par Flutter.  
> `sigma_db` est la base PostgreSQL du backend. Ce sont deux choses **totalement différentes**.

### Fichier `.env` du backend

```env
DATABASE_URL=postgresql://sigma_user:SigmaMF2024!@localhost:5432/sigma_db
SECRET_KEY=SigmaMicroFinance-SecretKey-2024-LAN-Server-Secure
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=480
REFRESH_TOKEN_EXPIRE_DAYS=7
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
```

---

## Sur quelle machine lancer le serveur ?

```
┌──────────────────────────────────────────────────────────────┐
│  PC DÉVELOPPEUR (votre machine)                              │
│  → Lancer le backend pour TESTER et DÉVELOPPER              │
│  → URL : http://localhost:8000                               │
│  → Commande : uvicorn main:app --reload                      │
│  → pgAdmin → connexion sur localhost                         │
└──────────────────────────────────────────────────────────────┘

≠ (ce sont deux contextes différents)

┌──────────────────────────────────────────────────────────────┐
│  PC SERVEUR DU CLIENT (production)                           │
│  → Le backend tourne EN PERMANENCE comme service Windows     │
│  → Installé une seule fois via install_serveur.bat           │
│  → URL : http://[IP_DU_SERVEUR]:8000                         │
│  → Tous les postes de l'agence s'y connectent via le LAN     │
└──────────────────────────────────────────────────────────────┘
```

**En résumé :** vous lancez le serveur sur votre machine pour développer et tester. Le client a son propre PC serveur sur lequel le même backend est installé en production via `install_serveur.bat`.

---

## Prérequis

- Python 3.11+
- PostgreSQL 15+
- pip

---

## Installation et démarrage sur votre PC (développement)

### Étape 1 — Créer la base PostgreSQL

Ouvrir **pgAdmin 4** sur votre machine, se connecter avec :

| Champ | Valeur |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| Database | `postgres` |
| User | `postgres` |
| Password | *(mot de passe défini à l'installation de PostgreSQL)* |

Cliquer **Connect & Open PSQL**, puis taper dans le terminal :

```sql
CREATE USER sigma_user WITH PASSWORD 'SigmaMF2024!';
CREATE DATABASE sigma_db OWNER sigma_user;
GRANT ALL PRIVILEGES ON DATABASE sigma_db TO sigma_user;
\q
```

> La base s'appelle `sigma_db` — ne pas confondre avec `sigma_microfinance.db` qui est le fichier SQLite local de Flutter.

### Étape 2 — Configurer l'environnement Python

```bash
cd c:\Users\LEGION\Desktop\Project\SIGMA\backend

python -m venv venv
venv\Scripts\activate

pip install -r requirements.txt
```

### Étape 3 — Configurer le `.env`

```bash
copy .env.example .env
```

Ouvrir `.env` et vérifier/modifier :

```env
DATABASE_URL=postgresql://sigma_user:SigmaMF2024!@localhost:5432/sigma_db
SECRET_KEY=SigmaMicroFinance-SecretKey-2024-LAN-Server-Secure
```

### Étape 4 — Initialiser la base de données

```bash
alembic upgrade head
python install/create_admin.py
```

Cela crée toutes les tables et le compte admin par défaut (`admin` / `Admin2024!`).

### Étape 5 — Démarrer le serveur

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Vérifier que ça fonctionne en ouvrant : `http://localhost:8000/docs`

---

## Installation chez le client (production)

### ✅ Méthode automatique — un seul clic

**Préparation sur votre PC dev :**

1. Lancer `install/build_exe.bat` → génère `install/sigma_server.exe`
2. Placer `postgresql-15-windows-x64.exe` dans `install/` si absent

**Sur le PC serveur du client :**

- Clic droit sur `install/install_serveur.bat`
- **"Exécuter en tant qu'administrateur"**
- Attendre ~5 minutes

Le script installe PostgreSQL, crée `sigma_db`, lance les migrations, crée le compte admin et installe le service Windows (démarrage automatique au boot).

---

## Accès au serveur

| URL | Description |
|---|---|
| `http://localhost:8000` | API locale (développement) |
| `http://[IP_SERVEUR]:8000` | API réseau (production LAN) |
| `http://[IP_SERVEUR]:8000/docs` | Documentation Swagger interactive |
| `http://[IP_SERVEUR]:8000/redoc` | Documentation ReDoc |
| `http://[IP_SERVEUR]:8000/health` | Vérification d'état |

Remplacer `[IP_SERVEUR]` par l'adresse IP fixe du PC serveur (ex: `192.168.1.100`).  
Pour trouver cette IP : sur le PC serveur → `cmd` → `ipconfig` → relever l'**Adresse IPv4**.

---

## Identifiants par défaut

| Compte | Utilisateur | Mot de passe |
|---|---|---|
| Application SIGMA | `admin` | `Admin2024!` |
| PostgreSQL (app) | `sigma_user` | `SigmaMF2024!` |
| PostgreSQL (admin) | `postgres` | *(défini à l'installation)* |

> ⚠️ Changer ces mots de passe après le premier démarrage en production.

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
    │   ├── config.py         # Variables d'environnement (.env)
    │   ├── database.py       # Connexion PostgreSQL (sigma_db)
    │   └── security.py       # JWT, bcrypt, dépendances auth
    ├── models/               # Modèles SQLAlchemy (32 tables)
    ├── schemas/              # Schémas Pydantic (validation)
    ├── routers/              # 13 routes API par module
    ├── services/
    │   ├── accounting_service.py   # Pont comptable automatique
    │   ├── penalty_service.py      # Calcul pénalités de retard
    │   └── scoring_service.py      # Score crédit dynamique
    └── jobs/
        ├── scheduler.py            # APScheduler
        ├── daily_penalties.py      # Job 00h05 — pénalités
        ├── monthly_interests.py    # Job 1er du mois — intérêts épargne
        └── nightly_scoring.py      # Job 02h00 — scores crédit
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
