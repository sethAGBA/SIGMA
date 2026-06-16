"""
Installe SIGMA API comme service Windows.
Le serveur démarrera automatiquement à chaque boot du PC serveur.

Utilise NSSM (Non-Sucking Service Manager) si disponible,
sinon crée une tâche planifiée Windows comme fallback.
"""
import os
import sys
import subprocess
import winreg

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INSTALL_DIR = os.path.join(BACKEND_DIR, "install")
SERVICE_NAME = "SIGMAMicroFinance"
SERVICE_DISPLAY = "SIGMA Micro-Finance API"


def install_via_nssm():
    """Installation via NSSM (méthode préférée)."""
    nssm_path = os.path.join(INSTALL_DIR, "nssm.exe")
    if not os.path.exists(nssm_path):
        return False

    python_exe = os.path.join(BACKEND_DIR, "venv", "Scripts", "python.exe")
    uvicorn_script = os.path.join(BACKEND_DIR, "venv", "Scripts", "uvicorn.exe")
    main_py = os.path.join(BACKEND_DIR, "main.py")

    # Installer le service
    subprocess.run([nssm_path, "install", SERVICE_NAME, python_exe,
                    f'"{uvicorn_script}" main:app --host 0.0.0.0 --port 8000'],
                   capture_output=True)
    subprocess.run([nssm_path, "set", SERVICE_NAME, "AppDirectory", BACKEND_DIR],
                   capture_output=True)
    subprocess.run([nssm_path, "set", SERVICE_NAME, "DisplayName", SERVICE_DISPLAY],
                   capture_output=True)
    subprocess.run([nssm_path, "set", SERVICE_NAME, "Description",
                    "Serveur API REST pour SIGMA Micro-Finance"],
                   capture_output=True)
    subprocess.run([nssm_path, "set", SERVICE_NAME, "Start", "SERVICE_AUTO_START"],
                   capture_output=True)

    # Démarrer le service
    result = subprocess.run([nssm_path, "start", SERVICE_NAME], capture_output=True)
    return result.returncode == 0


def install_via_task_scheduler():
    """Fallback : tâche planifiée Windows au démarrage."""
    python_exe = os.path.join(BACKEND_DIR, "venv", "Scripts", "python.exe")
    start_script = os.path.join(INSTALL_DIR, "start_server.bat")

    # Créer le script de démarrage
    with open(start_script, "w") as f:
        f.write(f'@echo off\n')
        f.write(f'cd /d "{BACKEND_DIR}"\n')
        f.write(f'call venv\\Scripts\\activate.bat\n')
        f.write(f'uvicorn main:app --host 0.0.0.0 --port 8000\n')

    # Créer la tâche planifiée
    cmd = [
        "schtasks", "/create", "/tn", SERVICE_NAME,
        "/tr", f'"{start_script}"',
        "/sc", "ONSTART",
        "/ru", "SYSTEM",
        "/f",
        "/rl", "HIGHEST",
    ]
    result = subprocess.run(cmd, capture_output=True)
    if result.returncode == 0:
        # Lancer immédiatement
        subprocess.run(["schtasks", "/run", "/tn", SERVICE_NAME], capture_output=True)
        return True
    return False


if __name__ == "__main__":
    print("Installation du service Windows SIGMA...")

    if install_via_nssm():
        print("Service installé via NSSM.")
    elif install_via_task_scheduler():
        print("Tâche planifiée Windows créée (démarrage automatique au boot).")
    else:
        print("Impossible d'installer le service automatiquement.")
        sys.exit(1)
