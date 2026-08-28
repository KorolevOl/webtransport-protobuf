@echo off
setlocal
title [2/5] Node Server (WT-edge TCP :8444)

cd /d "%~dp0"
if not exist "webtransport-protobuf-nodejs-server\package.json" (
    echo [SERVER] FATAL: start-server.bat must run from repository root
    pause
    exit /b 1
)

cd webtransport-protobuf-nodejs-server
echo ============================================
echo  Node server (transport-wt-edge)
echo  TCP relay listen :127.0.0.1:8444  (from Go edge)
echo  Envelope codec + auth domain
echo ============================================
rem Active plugin set (order enforced by `prestart` = check-plugin-order --write .env).
rem transport-wt-edge is the SEAM transport; transport-http is NOT loaded here (would be FATAL: two transports).
set "AWP_PLUGINS=transport-wt-edge,auth-store-memory,pwd-scrypt,tokens-hmac,rate-window,auth"
npm run dev
