@echo off
title SIGMA Micro-Finance - Installation Serveur
color 0A
chcp 65001 > nul
setlocal EnableDelayedExpansion

echo.
echo  ========================================
echo   SIGMA Micro-Finance - Installation
echo  ========================================
echo.

:: Droits administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERREUR] Lancer ce script en tant qu'Administrateur.
    echo Clic droit ^> "Executer en tant qu'administrateur"
    pause
    exit /b 1
)

set SCRIPT_DIR=%~dp0
set BACKEND_DIR=%SCRIPT_DIR%..
set LOG_FILE=%SCRIPT_DIR%install.log
set USE_EXE=0

echo [%date% %time%] Debut installation > "%LOG_FILE%"

:: ============================================================
echo [1/4] Verification du moteur SIGMA...

if exist "%SCRIPT_DIR%sigma_server.exe" (
    echo  Mode EXE : sigma_server.exe trouve. Python non necessaire.
    set USE_EXE=1
) else (
    echo  Mode Python : sigma_server.exe absent, recherche Python...
    python --version >nul 2>&1
    if !errorLevel! neq 0 (
        echo.
        echo  [ERREUR] Ni sigma_server.exe ni Python ne sont disponibles.
        echo.
        echo  SOLUTION 1 (recommandee - aucune installation requise) :
        echo    Sur votre PC de developpement, lancez build_exe.bat
        echo    Copiez le fichier sigma_server.exe genere dans ce dossier.
        echo    Relancez install_serveur.bat.
        echo.
        echo  SOLUTION 2 (si vous avez internet) :
        echo    Allez sur https://www.python.org/downloads/
        echo    Telechargez Python 3.11, cochez "Add Python to PATH"
        echo    Redemarrez ce script apres installation.
        echo.
        pause
        exit /b 1
    )
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
    echo  Python !PY_VER! OK
)

:: ============================================================
echo [2/4] Verification de PostgreSQL...

pg_isready -q >nul 2>&1
if %errorLevel% neq 0 (
    :: Chercher PostgreSQL dans les chemins habituels
    set PG_FOUND=0
    if exist "C:\Program Files\PostgreSQL\15\bin\pg_isready.exe" set PG_FOUND=1
    if exist "C:\Program Files\PostgreSQL\16\bin\pg_isready.exe" set PG_FOUND=1
    if exist "C:\Program Files\PostgreSQL\14\bin\pg_isready.exe" set PG_FOUND=1

    if !PG_FOUND! == 0 (
        if exist "%SCRIPT_DIR%postgresql-15-windows-x64.exe" (
            echo  Installation PostgreSQL 15 en cours...
            "%SCRIPT_DIR%postgresql-15-windows-x64.exe" --mode unattended --superpassword sigma2024 --servicename postgresql-15 --serverport 5432 >> "%LOG_FILE%" 2>&1
            if !errorLevel! neq 0 (
                echo  [ERREUR] Installation PostgreSQL echouee. Voir install.log
                pause
                exit /b 1
            )
            echo  PostgreSQL installe.
            :: Ajouter au PATH pour la session courante
            set PATH=%PATH%;C:\Program Files\PostgreSQL\15\bin
            timeout /t 8 /nobreak > nul
        ) else (
            echo.
            echo  [ERREUR] PostgreSQL non installe et installateur absent.
            echo.
            echo  Telechargez postgresql-15-windows-x64.exe depuis :
            echo  https://www.postgresql.org/download/windows/
            echo  Placez-le dans ce dossier et relancez.
            echo.
            pause
            exit /b 1
        )
    ) else (
        :: Démarrer le service si trouvé mais non actif
        net start postgresql-15 >nul 2>&1
        net start postgresql-x64-15 >nul 2>&1
        net start postgresql-x64-16 >nul 2>&1
        timeout /t 3 /nobreak > nul
        echo  PostgreSQL trouve et demarre.
    )
) else (
    echo  PostgreSQL actif. OK
)

:: Ajouter le bin PostgreSQL au PATH si pas encore dedans
for %%v in (16 15 14 13) do (
    if exist "C:\Program Files\PostgreSQL\%%v\bin\psql.exe" (
        set PATH=!PATH!;C:\Program Files\PostgreSQL\%%v\bin
        goto :pg_path_done
    )
)
:pg_path_done

:: ============================================================
echo [3/4] Creation base de donnees et configuration...

set PGPASSWORD=sigma2024
psql -U postgres -c "\l" >nul 2>&1
if %errorLevel% neq 0 (
    set PGPASSWORD=postgres
    psql -U postgres -c "\l" >nul 2>&1
)

:: Créer user et base si inexistants
psql -U postgres -c "CREATE USER sigma_user WITH PASSWORD 'SigmaMF2024!';" >> "%LOG_FILE%" 2>&1
psql -U postgres -c "CREATE DATABASE sigma_db OWNER sigma_user;" >> "%LOG_FILE%" 2>&1
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE sigma_db TO sigma_user;" >> "%LOG_FILE%" 2>&1
echo  Base de donnees sigma_db configuree.

:: Créer le .env si absent
cd /d "%BACKEND_DIR%"
if not exist ".env" (
    (
        echo DATABASE_URL=postgresql://sigma_user:SigmaMF2024!@localhost:5432/sigma_db
        echo SECRET_KEY=SigmaMicroFinance-SecretKey-2024-LAN-Secure-Install
        echo ALGORITHM=HS256
        echo ACCESS_TOKEN_EXPIRE_MINUTES=480
        echo REFRESH_TOKEN_EXPIRE_DAYS=7
        echo SERVER_HOST=0.0.0.0
        echo SERVER_PORT=8000
    ) > .env
    echo  Fichier .env cree.
)

:: Migrations et admin selon le mode
if !USE_EXE! == 1 (
    echo  Initialisation base de donnees via executable...
    "%SCRIPT_DIR%sigma_server.exe" --init-db >> "%LOG_FILE%" 2>&1
) else (
    echo  Installation dependances Python...
    if not exist "venv" python -m venv venv >> "%LOG_FILE%" 2>&1
    call venv\Scripts\activate.bat
    pip install -r requirements.txt -q >> "%LOG_FILE%" 2>&1
    echo  Migrations base de donnees...
    alembic upgrade head >> "%LOG_FILE%" 2>&1
    python install\create_admin.py >> "%LOG_FILE%" 2>&1
)
echo  Base de donnees initialisee.

:: ============================================================
echo [4/4] Installation service Windows (demarrage automatique)...

python install\install_service.py >> "%LOG_FILE%" 2>&1
if !errorLevel! neq 0 (
    echo  Service non installe - creation raccourci demarrage...
    :: Créer un raccourci dans le dossier Démarrage Windows
    set STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
    copy "%SCRIPT_DIR%demarrer_serveur.bat" "!STARTUP!\SIGMA_Serveur.bat" >nul 2>&1
    echo  Raccourci de demarrage automatique cree.
)

:: Démarrer le serveur maintenant
echo  Demarrage du serveur SIGMA...
if !USE_EXE! == 1 (
    start "" "%SCRIPT_DIR%sigma_server.exe"
) else (
    start "" "%SCRIPT_DIR%demarrer_serveur.bat"
)
timeout /t 4 /nobreak > nul

:: Récupérer l'IP locale
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"Adresse IPv4" ^| findstr /v "127.0.0.1"') do (
    set LOCAL_IP=%%a
    set LOCAL_IP=!LOCAL_IP: =!
    goto :ip_done
)
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4 Address" ^| findstr /v "127.0.0.1"') do (
    set LOCAL_IP=%%a
    set LOCAL_IP=!LOCAL_IP: =!
    goto :ip_done
)
set LOCAL_IP=VOTRE_IP_SERVEUR
:ip_done

:: ============================================================
echo.
echo  ============================================
echo   INSTALLATION TERMINEE AVEC SUCCES !
echo  ============================================
echo.
echo  Serveur API       : http://localhost:8000
echo  Documentation     : http://localhost:8000/docs
echo  Acces LAN         : http://!LOCAL_IP!:8000
echo.
echo  Identifiants :
echo    Utilisateur : admin
echo    Mot de passe : Admin2024!
echo.
echo  IMPORTANT : Changez le mot de passe apres la premiere connexion.
echo.
echo [%date% %time%] Installation terminee. >> "%LOG_FILE%"

pause
