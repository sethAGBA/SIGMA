@echo off
title SIGMA — Serveur API
color 0A
chcp 65001 > nul

cd /d "%~dp0.."
call venv\Scripts\activate.bat

echo.
echo  ================================
echo   SIGMA Micro-Finance — Serveur
echo  ================================
echo.
echo  Serveur en cours de demarrage...
echo  Acces local  : http://localhost:8000
echo  Documentation: http://localhost:8000/docs
echo.
echo  NE PAS FERMER CETTE FENETRE.
echo  Pour arreter le serveur : Ctrl+C
echo.

uvicorn main:app --host 0.0.0.0 --port 8000
