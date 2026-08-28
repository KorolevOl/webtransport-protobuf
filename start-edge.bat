@echo off
setlocal
title [1/5] Go Edge (H3/QUIC :9443)

cd /d "%~dp0"
if not exist "webtransport-protobuf-go-edge\go.mod" (
    echo [EDGE] FATAL: start-edge.bat must run from repository root
    pause
    exit /b 1
)

rem Browser (Chromium) requires a pin-cert with lifetime < ~14 days.
rem `leaf-short` is the short-lived cert; `leaf` (10y) would be rejected by `serverCertificateHashes`.
set "AWP_EDGE_CERT_FILE=%CD%\webtransport-protobuf-certs\leaf-short\leaf.pem"
set "AWP_EDGE_KEY_FILE=%CD%\webtransport-protobuf-certs\leaf-short\leaf.key"
set "AWP_EDGE_ADDR=127.0.0.1:9443"
set "AWP_EDGE_NODE_ADDR=127.0.0.1:8444"

cd webtransport-protobuf-go-edge
echo ============================================
echo  Go Edge
echo  QUIC/H3 listen: 127.0.0.1:9443
echo  relays to Node:  127.0.0.1:8444
echo  cert: %AWP_EDGE_CERT_FILE%
echo ============================================
go run ./cmd/edge
