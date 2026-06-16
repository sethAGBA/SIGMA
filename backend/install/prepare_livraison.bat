@echo off
title SIGMA — Preparation dossier de livraison
color 0B
chcp 65001 > nul
setlocal EnableDelayedExpansion

echo.
echo  ============================================
echo   SIGMA — Preparation de la livraison client
echo  ============================================
echo.

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..\..
set OUTPUT_DIR=%PROJECT_DIR%\..\SIGMA_Livraison
set DATE_STR=%date:~6,4%-%date:~3,2%-%date:~0,2%

echo  Dossier de sortie : %OUTPUT_DIR%
echo.

:: Vérifier que l'exe serveur existe
if not exist "%SCRIPT_DIR%sigma_server.exe" (
    echo  [ATTENTION] sigma_server.exe absent.
    echo  Lancez d'abord build_exe.bat pour le generer.
    echo.
    set /p BUILD_NOW="Lancer build_exe.bat maintenant ? (O/N) : "
    if /i "!BUILD_NOW!" == "O" (
        call "%SCRIPT_DIR%build_exe.bat"
    ) else (
        echo  Preparation annulee.
        pause
        exit /b 1
    )
)

:: Vérifier que l'app Flutter est compilée
set FLUTTER_BUILD=%PROJECT_DIR%\build\windows\x64\runner\Release
if not exist "%FLUTTER_BUILD%\sigma.exe" (
    echo  [ATTENTION] sigma.exe Flutter absent.
    echo  Lancez : flutter build windows --release
    echo  depuis le dossier du projet Flutter.
    echo.
    echo  Continuer sans l'application Flutter ? (SERVEUR uniquement)
    set /p CONTINUE_NO_APP="(O/N) : "
    if /i "!CONTINUE_NO_APP!" neq "O" (
        echo  Preparation annulee.
        pause
        exit /b 1
    )
)

:: Nettoyer et créer la structure de sortie
echo  Nettoyage du dossier precedent...
if exist "%OUTPUT_DIR%" rmdir /s /q "%OUTPUT_DIR%"
mkdir "%OUTPUT_DIR%"
mkdir "%OUTPUT_DIR%\SERVEUR"
mkdir "%OUTPUT_DIR%\APPLICATION"

:: ── DOSSIER SERVEUR ──────────────────────────────────────────
echo  Copie des fichiers serveur...

copy "%SCRIPT_DIR%sigma_server.exe" "%OUTPUT_DIR%\SERVEUR\" > nul
copy "%SCRIPT_DIR%install_serveur.bat" "%OUTPUT_DIR%\SERVEUR\" > nul
copy "%SCRIPT_DIR%demarrer_serveur.bat" "%OUTPUT_DIR%\SERVEUR\" > nul
copy "%SCRIPT_DIR%create_admin.py" "%OUTPUT_DIR%\SERVEUR\" > nul 2>&1
copy "%SCRIPT_DIR%install_service.py" "%OUTPUT_DIR%\SERVEUR\" > nul 2>&1
copy "%SCRIPT_DIR%LISEZ_MOI_INSTALLATION.txt" "%OUTPUT_DIR%\SERVEUR\" > nul

:: NSSM pour le service Windows
if exist "%SCRIPT_DIR%nssm-2.24\nssm-2.24\win64\nssm.exe" (
    mkdir "%OUTPUT_DIR%\SERVEUR\nssm"
    copy "%SCRIPT_DIR%nssm-2.24\nssm-2.24\win64\nssm.exe" "%OUTPUT_DIR%\SERVEUR\nssm\" > nul
    echo  NSSM copie.
)

:: PostgreSQL si présent
if exist "%SCRIPT_DIR%postgresql-15.8-1-windows-x64.exe" (
    copy "%SCRIPT_DIR%postgresql-15.8-1-windows-x64.exe" "%OUTPUT_DIR%\SERVEUR\" > nul
    echo  Installateur PostgreSQL copie.
)

echo  Dossier SERVEUR pret.

:: ── DOSSIER APPLICATION ──────────────────────────────────────
if exist "%FLUTTER_BUILD%\sigma.exe" (
    echo  Copie de l'application Flutter...
    xcopy "%FLUTTER_BUILD%\*" "%OUTPUT_DIR%\APPLICATION\" /E /I /Q > nul
    echo  Dossier APPLICATION pret.
) else (
    echo  (Application Flutter ignoree — dossier APPLICATION vide)
)

:: ── FICHIER VERSION ──────────────────────────────────────────
(
    echo SIGMA Micro-Finance
    echo Version de livraison : %DATE_STR%
    echo.
    echo Contenu :
    echo   SERVEUR\    ^> A installer sur le PC serveur
    echo   APPLICATION\^> A copier sur chaque poste client
    echo.
    echo Voir SERVEUR\LISEZ_MOI_INSTALLATION.txt pour les instructions.
) > "%OUTPUT_DIR%\VERSION.txt"

:: ── RÉSUMÉ ───────────────────────────────────────────────────
echo.
echo  ============================================
echo   LIVRAISON PRETE !
echo  ============================================
echo.
echo  Dossier cree : %OUTPUT_DIR%
echo.
echo  Contenu :
dir "%OUTPUT_DIR%\SERVEUR" /b 2>nul | findstr /v "^$" > tmplist.txt
for /f %%f in (tmplist.txt) do echo    SERVEUR\%%f
del tmplist.txt > nul 2>&1
echo.
if exist "%OUTPUT_DIR%\APPLICATION\sigma.exe" (
    echo    APPLICATION\sigma.exe  ^(+ DLL Flutter^)
) else (
    echo    APPLICATION\  ^(vide - flutter build manquant^)
)
echo.
echo  Ce dossier peut etre copie sur une cle USB
echo  et livre directement chez le client.
echo.

pause
