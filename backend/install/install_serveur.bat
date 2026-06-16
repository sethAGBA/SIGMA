@echo off
title SIGMA Micro-Finance — Installation Serveur
color 0A
chcp 65001 > nul

echo.
echo  ███████╗██╗ ██████╗ ███╗   ███╗ █████╗
echo  ██╔════╝██║██╔════╝ ████╗ ████║██╔══██╗
echo  ███████╗██║██║  ███╗██╔████╔██║███████║
echo  ╚════██║██║██║   ██║██║╚██╔╝██║██╔══██║
echo  ███████║██║╚██████╔╝██║ ╚═╝ ██║██║  ██║
echo  ╚══════╝╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝
echo.
echo  Installation automatique du serveur SIGMA
echo  ==========================================
echo.

:: Vérifier les droits administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERREUR] Ce script doit etre lance en tant qu'Administrateur.
    echo Clic droit sur le fichier ^> "Executer en tant qu'administrateur"
    pause
    exit /b 1
)

set SCRIPT_DIR=%~dp0
set BACKEND_DIR=%SCRIPT_DIR%..
set LOG_FILE=%SCRIPT_DIR%install.log

echo [%date% %time%] Debut de l'installation > "%LOG_FILE%"

:: ============================================================
echo [1/6] Verification de Python...
python --version > nul 2>&1
if %errorLevel% neq 0 (
    echo  Python non trouve. Lancement de l'installateur Python...
    if exist "%SCRIPT_DIR%python-3.11.9-amd64.exe" (
        echo  Installation de Python 3.11...
        "%SCRIPT_DIR%python-3.11.9-amd64.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
        if %errorLevel% neq 0 (
            echo [ERREUR] L'installation de Python a echoue. >> "%LOG_FILE%"
            echo [ERREUR] Impossible d'installer Python automatiquement.
            echo Telechargez Python 3.11 sur https://www.python.org/downloads/
            pause
            exit /b 1
        )
        echo  Python installe avec succes.
        :: Rafraîchir le PATH
        call refreshenv > nul 2>&1
    ) else (
        echo [ERREUR] python-3.11.9-amd64.exe introuvable dans le dossier install\. >> "%LOG_FILE%"
        echo [ERREUR] Fichier python-3.11.9-amd64.exe absent du dossier install\.
        echo Telechargez Python 3.11 depuis https://www.python.org/downloads/
        echo et placez-le dans le dossier install\
        pause
        exit /b 1
    )
) else (
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
    echo  Python %PY_VER% detecte. OK
)

:: ============================================================
echo [2/6] Verification de PostgreSQL...
pg_isready > nul 2>&1
if %errorLevel% neq 0 (
    echo  PostgreSQL non detecte. Lancement de l'installateur...
    if exist "%SCRIPT_DIR%postgresql-15-windows-x64.exe" (
        echo  Installation de PostgreSQL 15 (mot de passe admin: sigma2024)...
        "%SCRIPT_DIR%postgresql-15-windows-x64.exe" --mode unattended --superpassword sigma2024 --servicename postgresql-15 --servicepassword sigma2024 --serverport 5432
        if %errorLevel% neq 0 (
            echo [ERREUR] L'installation de PostgreSQL a echoue. >> "%LOG_FILE%"
            echo [ERREUR] Impossible d'installer PostgreSQL automatiquement.
            pause
            exit /b 1
        )
        echo  PostgreSQL 15 installe avec succes.
        timeout /t 5 /nobreak > nul
    ) else (
        echo [ERREUR] Installateur PostgreSQL absent du dossier install\. >> "%LOG_FILE%"
        echo [ERREUR] Fichier postgresql-15-windows-x64.exe absent du dossier install\.
        echo Telechargez PostgreSQL 15 depuis https://www.postgresql.org/download/windows/
        pause
        exit /b 1
    )
) else (
    echo  PostgreSQL detecte. OK
)

:: ============================================================
echo [3/6] Creation de la base de donnees...
set PGPASSWORD=sigma2024
psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='sigma_db'" | findstr "1 row" > nul 2>&1
if %errorLevel% neq 0 (
    echo  Creation utilisateur et base de donnees...
    psql -U postgres -c "CREATE USER sigma_user WITH PASSWORD 'SigmaMF2024!';" >> "%LOG_FILE%" 2>&1
    psql -U postgres -c "CREATE DATABASE sigma_db OWNER sigma_user;" >> "%LOG_FILE%" 2>&1
    psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE sigma_db TO sigma_user;" >> "%LOG_FILE%" 2>&1
    echo  Base de donnees sigma_db creee.
) else (
    echo  Base de donnees sigma_db deja existante. OK
)

:: ============================================================
echo [4/6] Installation des dependances Python...
cd /d "%BACKEND_DIR%"
if not exist "venv" (
    python -m venv venv >> "%LOG_FILE%" 2>&1
    echo  Environnement virtuel cree.
)
call venv\Scripts\activate.bat
pip install -r requirements.txt --quiet >> "%LOG_FILE%" 2>&1
if %errorLevel% neq 0 (
    echo [ERREUR] Echec installation dependances Python. Voir install.log >> "%LOG_FILE%"
    echo [ERREUR] Echec lors de pip install. Consultez install\install.log
    pause
    exit /b 1
)
echo  Dependances Python installees.

:: ============================================================
echo [5/6] Configuration de l'application...
if not exist ".env" (
    :: Récupérer l'IP locale automatiquement
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4" ^| findstr /v "127.0.0.1" ^| head -1') do (
        set LOCAL_IP=%%a
        set LOCAL_IP=!LOCAL_IP: =!
    )
    (
        echo DATABASE_URL=postgresql://sigma_user:SigmaMF2024!@localhost:5432/sigma_db
        echo SECRET_KEY=SigmaMicroFinance-SecretKey-2024-LAN-Server-Secure
        echo ALGORITHM=HS256
        echo ACCESS_TOKEN_EXPIRE_MINUTES=480
        echo REFRESH_TOKEN_EXPIRE_DAYS=7
        echo SERVER_HOST=0.0.0.0
        echo SERVER_PORT=8000
    ) > .env
    echo  Fichier .env cree.
) else (
    echo  Fichier .env existant conserve.
)

:: Lancer les migrations Alembic
echo  Initialisation de la base de donnees...
call venv\Scripts\activate.bat
alembic upgrade head >> "%LOG_FILE%" 2>&1
if %errorLevel% neq 0 (
    echo [ERREUR] Echec des migrations Alembic. Voir install.log >> "%LOG_FILE%"
    echo [ERREUR] Echec des migrations. Consultez install\install.log
    pause
    exit /b 1
)
echo  Structure de la base de donnees creee.

:: Créer le premier utilisateur admin
python install\create_admin.py >> "%LOG_FILE%" 2>&1
echo  Compte administrateur cree (admin / Admin2024!).

:: ============================================================
echo [6/6] Installation du service Windows...
python install\install_service.py >> "%LOG_FILE%" 2>&1
if %errorLevel% neq 0 (
    echo  (Service Windows non installe — le serveur devra etre demarre manuellement)
) else (
    echo  Service Windows SIGMA installe et demarre.
)

:: ============================================================
echo.
echo  ============================================
echo   INSTALLATION TERMINEE AVEC SUCCES !
echo  ============================================
echo.
echo  Serveur API : http://localhost:8000
echo  Documentation : http://localhost:8000/docs
echo.
echo  Identifiants administrateur :
echo    Utilisateur : admin
echo    Mot de passe : Admin2024!
echo.

:: Obtenir l'IP locale pour affichage
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"Adresse IPv4"') do (
    set LOCAL_IP=%%a
    set LOCAL_IP=!LOCAL_IP: =!
    goto :found_ip
)
:found_ip
echo  Acces depuis les autres postes : http://!LOCAL_IP!:8000
echo.
echo [%date% %time%] Installation terminee avec succes. >> "%LOG_FILE%"

pause
