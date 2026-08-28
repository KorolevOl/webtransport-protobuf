@echo off
setlocal
title [3/5] Angular Frontend (ng serve :4300)

cd /d "%~dp0"
if not exist "webtransport-protobuf-angular-web\package.json" (
    echo [WEB] FATAL: start-web.bat must run from repository root
    pause
    exit /b 1
)

cd webtransport-protobuf-angular-web
echo ============================================
echo  Angular dev server (ng serve)
echo  frontend : http://localhost:4300
echo  webtransport endpoint: https://127.0.0.1:9443/awp
echo ============================================
npm start -- --port 4300
