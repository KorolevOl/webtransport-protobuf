@echo off
setlocal EnableExtensions
title AWP Bootstrap (submodules + deps + launch)

rem ================================================================
rem  bootstrap.bat - one-shot launcher for webtransport-protobuf.
rem
rem  Run from repo root (double-click). It:
rem    1. verifies toolchain     (git, node, npm, go)
rem    2. pulls submodules       (git submodule update --init --recursive)
rem    3. installs deps          (npm ci x2, proto:gen x2, go mod download)
rem    4. checks dev-Cert        (Chromium WebTransport pinning, leaf-short must be valid)
rem    5. launches 3 windows     (edge -> node -> angular)
rem  Pure-ASCII on purpose (ru-Windows CP866 parse-safe; see .bat pitfalls).
rem ================================================================

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
cd /d "%ROOT%"

echo ================================================================
echo  [bootstrap] webtransport-protobuf
echo  root: %ROOT%
echo ================================================================
echo.

rem ---------- 1. toolchain ----------
where git >nul 2>nul
if errorlevel 1 (
    echo [toolchain] MISSING: git  - need Git for Windows
    pause
    exit /b 1
)
echo [toolchain] git   OK
where node >nul 2>nul
if errorlevel 1 (
    echo [toolchain] MISSING: node  - need Node.js 24
    pause
    exit /b 1
)
echo [toolchain] node  OK
where npm >nul 2>nul
if errorlevel 1 (
    echo [toolchain] MISSING: npm  - need npm 11
    pause
    exit /b 1
)
echo [toolchain] npm   OK
where go >nul 2>nul
if errorlevel 1 (
    echo [toolchain] MISSING: go  - need Go 1.26 or newer
    pause
    exit /b 1
)
echo [toolchain] go    OK

rem ---------- 2. submodules ----------
echo.
rem Detect whether submodules are already checked out.
set "MISSING="
for %%d in (webtransport-protobuf-proto webtransport-protobuf-angular-web webtransport-protobuf-nodejs-server webtransport-protobuf-certs webtransport-protobuf-go-edge) do (
    if not exist "%%d" set "MISSING=1"
)
if defined MISSING (
    echo [submodules] not all 5 present, running: git submodule update --init --recursive
    git submodule update --init --recursive
    if errorlevel 1 (
        echo [submodules] FAILED. Check .gitmodules and network access to github.com.
        pause
        exit /b 1
    )
)

rem Re-verify all 5 subdirs exist after the update attempt.
set "MISSING2="
for %%d in (webtransport-protobuf-proto webtransport-protobuf-angular-web webtransport-protobuf-nodejs-server webtransport-protobuf-certs webtransport-protobuf-go-edge) do (
    if not exist "%%d" (
        set "MISSING2=1"
        echo [submodules] STILL MISSING after update: %%d
    )
)
if defined MISSING2 (
    pause
    exit /b 1
)
echo [submodules] all 5 present.

rem ---------- 3. dependencies ----------
echo.
echo [deps] web    : npm ci
pushd webtransport-protobuf-angular-web
call npm ci
if errorlevel 1 (
    echo [deps] web npm ci FAILED.
    popd
    pause
    exit /b 1
)
popd
echo.
echo [deps] server : npm ci
pushd webtransport-protobuf-nodejs-server
call npm ci
if errorlevel 1 (
    echo [deps] server npm ci FAILED.
    popd
    pause
    exit /b 1
)
popd
echo.
echo [deps] proto  : buf generate (web)
pushd webtransport-protobuf-angular-web
call npm run proto:gen
if errorlevel 1 (
    echo [deps] web proto:gen FAILED.
    popd
    pause
    exit /b 1
)
popd
echo [deps] proto  : buf generate (server)
pushd webtransport-protobuf-nodejs-server
call npm run proto:gen
if errorlevel 1 (
    echo [deps] server proto:gen FAILED.
    popd
    pause
    exit /b 1
)
popd
echo.
echo [deps] edge   : go mod download
pushd webtransport-protobuf-go-edge
go mod download
if errorlevel 1 (
    echo [deps] go mod download FAILED.
    popd
    pause
    exit /b 1
)
popd
echo [deps] all deps ready.

rem ---------- 4. cert sanity ----------
echo.
echo [certs] leaf-short expiry (Chromium WebTransport pinning requires lifetime b. ~14 days):
openssl x509 -in webtransport-protobuf-certs\leaf-short\leaf.pem -noout -enddate 2>nul
echo        If expired: regenerate via webtransport-protobuf-certs and update
echo        LEAF_SHORT_SHA256_HEX in webtransport-protobuf-angular-web/src/app/app.config.ts.

rem ---------- 5. launch ----------
echo.
echo ================================================================
echo  Launching:
echo    [edge   ] QUIC/H3      https://127.0.0.1:9443/awp   (cert: leaf-short)
echo    [server ] Node WT-edge TCP 127.0.0.1:8444           (Envelope codec + auth)
echo    [web    ] Angular      http://localhost:4300        (ng serve)
echo ================================================================
echo.
start "" "%~dp0start-edge.bat"
echo started edge
timeout /t 2 /nobreak >nul
start "" "%~dp0start-server.bat"
echo started server
start "" "%~dp0start-web.bat"
echo started web
echo.
echo All 3 windows launched. Open http://localhost:4300 in a Chromium-based browser
echo (Yandex Browser preferred).
echo
pause
exit /b 0
