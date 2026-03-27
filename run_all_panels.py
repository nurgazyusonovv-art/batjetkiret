import subprocess
import sys
import os

# Paths to each panel/project
BACKEND_PATH = os.path.abspath('.')
ADMIN_PANEL_PATH = os.path.join(BACKEND_PATH, 'admin-panel')
ENTERPRISE_PANEL_PATH = os.path.join(BACKEND_PATH, 'enterprise-panel')
FLUTTER_PATH = os.path.join(BACKEND_PATH, 'frontend')

processes = []

try:
    # Start backend (FastAPI)
    print('Starting backend...')
    backend_proc = subprocess.Popen([
        sys.executable, '-m', 'uvicorn', 'app.main:app', '--reload'
    ], cwd=BACKEND_PATH)
    processes.append(backend_proc)

    # Start admin panel (npm run dev)
    print('Starting admin panel...')
    admin_proc = subprocess.Popen([
        'npm', 'run', 'dev'
    ], cwd=ADMIN_PANEL_PATH)
    processes.append(admin_proc)

    # Start enterprise panel (npm run dev)
    print('Starting enterprise panel...')
    enterprise_proc = subprocess.Popen([
        'npm', 'run', 'dev'
    ], cwd=ENTERPRISE_PANEL_PATH)
    processes.append(enterprise_proc)

    # Start Flutter project (flutter run web)
    print('Starting Flutter project...')
    flutter_proc = subprocess.Popen([
        'flutter', 'run', '-d', 'web-server', '--web-port', '8080'
    ], cwd=FLUTTER_PATH)
    processes.append(flutter_proc)

    print('\nAll services started. Press Ctrl+C to stop all.')
    for proc in processes:
        proc.wait()

except KeyboardInterrupt:
    print('\nShutting down all services...')
    for proc in processes:
        proc.terminate()
    print('All services stopped.')
