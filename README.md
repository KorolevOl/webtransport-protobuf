# webtransport-protobuf

Корневой репо — **workspace-уровень**: `AGENTS.md` (роутер по темам), `README.md`,
`.gitignore`, `.gitmodules` и запускающие батники. Пять подрепо — **git-submodule'ы**;
имена папок совпадают с именами своих репо (список — в `.gitmodules`).

## Подрепо (что за что отвечает)

| Подрепо | Назначение (кратко) |
|---------|---------------------|
| `webtransport-protobuf-proto`        | **Protobuf-контракты** (единый `common/v1.Envelope` + доменные `auth/v1`…) — единственный источник типов обмена фронт↔бек. Каноны: `AGENTS.md`, `PROTOCOL.md`. |
| `webtransport-protobuf-angular-web`  | **Фронт** на Angular 22 (zoneless, Signal Forms, Taiga UI). WebTransport-адаптер (SEAM) + плагин `auth`, hot-swap http/webtransport. |
| `webtransport-protobuf-nodejs-server`| **Бек** на Node.js 24 (ESM, strict). Плагинный контейнер: `transport-wt-edge` (TCP:8444) + `auth` + кодеры Envelope. |
| `webtransport-protobuf-certs`        | **Dev-TLS**: self-signed dev-CA + leaf + `leaf-short` (короткий ECDSA P-256, <14 дней) — для Chromium-пиннинга WebTransport. `ca/`, `leaf/`, `leaf-short/`, `make-certs.mjs`. |
| `webtransport-protobuf-go-edge`      | **WebTransport-edge** на Go (quic-go / webtransport-go): H3/QUIC-слушатель `:9443`, байт-реле (фрейминг 4B BE length + payload) в Node `:8444`. |

## Быстрый старт (новый пользователь)

1. **Сделать clone** (важно: `--recurse-submodules`):
   ```bash
   git clone --recurse-submodules https://github.com/KorolevOl/webtransport-protobuf
   cd webtransport-protobuf
   ```
   Без флага — `bootstrap.bat` сам подтянет подрепо.

2. **Запустить всё** (один клик):
   ```
   bootstrap.bat
   ```
   Скрипт: (a) проверяет `git`, `node`, `npm`, `go`; (b) `git submodule update --init --recursive`;
   (c) `npm ci` в `web` и `server` + `npm run proto:gen` + `go mod download`;
   (d) открывает **три окна**: Go edge, Node server, Angular.
   Отдельные окна: `start-edge.bat`, `start-server.bat`, `start-web.bat`.

3. **Открыть браузер** (Яндекс Browser / Chromium — WebTransport нужен в secure context):
   ```
   http://localhost:4300
   ```

## Разбор архитектуры (что и зачем)

```
+----------------+            +---------------------+            +-------------------+
|  Angular 22    |  WebTransp|   Go edge           |   TCP      |   Node 24         |
|  (ng serve)    |----H3/QUIC--> (quic-go)         |-----> relay ----> (transport-   |
|  :4300         |  :9443    |  :9443 listener     |  :8444    |    wt-edge) + auth |
+----------------+            +---------------------+            +-------------------+
     ITransport (SEAM, adapter)        byte relay 4B BE len + payload      ITransport (SEAM, TCP)
```

- **Фронт** знает только контракт `ITransport` (SEAM). Реализация — `WebTransportAdapter`
  (H3/QUIC, `serverCertificateHashes`-пиннинг) либо `HttpTransport` (dev-фолбэк, `:8443`).
- **Go edge** — тонкий байт-реле: читает фреймы с WT bidi-стрима и перекидывает в Node.
  НЕ декодирует Envelope, НЕ знает о бизнес-доменах — только транспортный шов.
- **Node** — бизнес: кодер Envelope + домен `auth` (логин/лог-аут/refresh).
- **Protobuf-контракт** — ОДИН: `webtransport-protobuf-proto/common/v1/envelope.proto`.
  Оба кода (web + server) генерируют тип из одного `.proto` (Buf + `protoc-gen-es`).

## Прочие файлы

- `AGENTS.md` — полный роутер по вопросам (тема → подрепо).
- `GETTING-STARTED.md` — **полный гид новичка**: запуск одним клином + разбор
  WebTransport + Protobuf «в пальцах» (схема процессов, фрейминг, `Envelope`,
  SEAM, чеклист браузера, команды).
- `bootstrap.bat` / `start-{edge,server,web}.bat` — запуст (один клик).
