"""
SIGMA Micro-Finance — Backend FastAPI
Point d'entrée principal du serveur API REST.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.database import create_tables
from app.jobs.scheduler import start_scheduler

# Import de tous les routers
from app.routers import (
    auth, clients, groupes, produits, prets, remboursements,
    epargne, caisse, comptabilite, agents, agencies, reporting, configuration,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Événements de démarrage et d'arrêt de l'application."""
    # Démarrage
    create_tables()
    start_scheduler()
    print("✅ SIGMA API démarrée — base de données et scheduler initialisés")
    yield
    # Arrêt
    from app.jobs.scheduler import scheduler
    if scheduler.running:
        scheduler.shutdown()
    print("🛑 SIGMA API arrêtée")


app = FastAPI(
    title="SIGMA Micro-Finance API",
    description="API REST pour la gestion de micro-finance SIGMA — déployée sur réseau local (LAN)",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS — autorisé pour tout le réseau local
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Réseau local uniquement — restreindre en prod si nécessaire
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Enregistrement de tous les routers avec préfixe /api/v1
PREFIX = "/api/v1"

app.include_router(auth.router, prefix=PREFIX)
app.include_router(clients.router, prefix=PREFIX)
app.include_router(groupes.router, prefix=PREFIX)
app.include_router(produits.router, prefix=PREFIX)
app.include_router(prets.router, prefix=PREFIX)
app.include_router(remboursements.router, prefix=PREFIX)
app.include_router(epargne.router, prefix=PREFIX)
app.include_router(caisse.router, prefix=PREFIX)
app.include_router(comptabilite.router, prefix=PREFIX)
app.include_router(agents.router, prefix=PREFIX)
app.include_router(agencies.router, prefix=PREFIX)
app.include_router(reporting.router, prefix=PREFIX)
app.include_router(configuration.router, prefix=PREFIX)


@app.get("/")
def root():
    return {"message": "SIGMA Micro-Finance API en ligne", "version": "1.0.0", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok", "service": "SIGMA API"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.SERVER_HOST,
        port=settings.SERVER_PORT,
        reload=True,
    )
