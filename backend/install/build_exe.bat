@echo off
title SIGMA — Build executable
color 0B
chcp 65001 > nul

echo.
echo  Construction de l'executable SIGMA (PyInstaller)
echo  =================================================
echo  A executer UNE SEULE FOIS sur votre PC de developpement.
echo  L'executable produit n'a pas besoin de Python installe.
echo.

cd /d "%~dp0.."

:: Vérifier Python (présent sur le PC dev)
python --version > nul 2>&1
if %errorLevel% neq 0 (
    echo [ERREUR] Python requis sur le PC de developpement pour builder.
    pause
    exit /b 1
)

:: Installer PyInstaller + dépendances dans le venv
call venv\Scripts\activate.bat 2>nul || (
    python -m venv venv
    call venv\Scripts\activate.bat
)

pip install -r requirements.txt --quiet
pip install pyinstaller --quiet

echo  Compilation en cours... (2-5 minutes)

:: Compiler main.py en exécutable unique
pyinstaller --onefile --name sigma_server --hidden-import=app.models.utilisateur ^
    --hidden-import=app.models.client ^
    --hidden-import=app.models.pret ^
    --hidden-import=app.models.epargne ^
    --hidden-import=app.models.caisse ^
    --hidden-import=app.models.comptabilite ^
    --hidden-import=app.models.remboursement ^
    --hidden-import=app.models.agent ^
    --hidden-import=app.models.agency ^
    --hidden-import=app.models.audit_log ^
    --hidden-import=app.models.groupe_solidaire ^
    --hidden-import=app.models.produit_financier ^
    --hidden-import=app.routers.auth ^
    --hidden-import=app.routers.clients ^
    --hidden-import=app.routers.prets ^
    --hidden-import=app.routers.remboursements ^
    --hidden-import=app.routers.epargne ^
    --hidden-import=app.routers.caisse ^
    --hidden-import=app.routers.comptabilite ^
    --hidden-import=app.routers.groupes ^
    --hidden-import=app.routers.produits ^
    --hidden-import=app.routers.agents ^
    --hidden-import=app.routers.agencies ^
    --hidden-import=app.routers.reporting ^
    --hidden-import=app.routers.configuration ^
    --hidden-import=apscheduler.schedulers.asyncio ^
    --hidden-import=apscheduler.triggers.cron ^
    --hidden-import=passlib.handlers.bcrypt ^
    --hidden-import=jose ^
    --collect-all=sqlalchemy ^
    --collect-all=alembic ^
    --noconfirm ^
    main.py

if %errorLevel% neq 0 (
    echo [ERREUR] La compilation a echoue.
    pause
    exit /b 1
)

:: Copier l'exe dans le dossier install
copy dist\sigma_server.exe install\sigma_server.exe > nul
echo  Executable cree : install\sigma_server.exe

echo.
echo  Vous pouvez maintenant livrer le dossier install\ chez le client.
echo  L'installateur utilisera sigma_server.exe sans Python.
echo.
pause
