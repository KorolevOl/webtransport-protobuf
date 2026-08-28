# GETTING-STARTED — как запустить и как устроено (для первого раза)

> Цель: ты зашёл в проект впервые, хочешь (1) запустить его одним нажатием и
> (2) понять, **как здесь работает WebTransport с Protobuf**. Всё ниже уже реализовано
> и проверено. Ссылки ведут на файлы.

---

## Часть 1. Запуск (5 минут)

### 0. что нужно на машине
| Инструмент | Версия | Зачем |
|---|---|---|
| Windows + Git (git-bash) | git 2.+ | клонирование, submodules |
| Node.js | 24 | фронт (Angular) и бек (Node server) |
| npm | 11 | установка зависимостей |
| Go | 1.26+ | WebTransport-edge (`quic-go`, нативный H3/QUIC) |
| Браузер | Chromium-совместимый | **Яндекс Browser** — первичный (WebTransport) |

> Почему Go, а не чистый Node? **Node.js 24 не имеет нативного QUIC**
> (`node:quic` не грузится). WebTransport по W3C/HTTP3 работает поверх QUIC,
> поэтому серверный QUIC-швейцарский нож держит **Go** (quic-go), а Node остаётся
> только бизнес-логикой.

### 1. клонировать
```bash
git clone --recurse-submodules https://github.com/KorolevOl/webtransport-protobuf
cd webtransport-protobuf
```
`-recurse-submodules` подтянет 5 подрепо. Если клонировали без флага —
`bootstrap.bat` сам выполнит `git submodule update --init --recursive`.

### 2. один клик
```
bootstrap.bat
```
Скрипт делает по порядку (и остановится, если что-то упало):
1. **Тулчейн**: `git`, `node`, `npm`, `go` — наличие.
2. **Submodules**: `git submodule update --init --recursive` (если подрепо пусты).
3. **Зависимости**: `npm ci` в `web` и `server`; `npm run proto:gen` (оба — генерация
   TS-типов из `.proto`); `go mod download`.
4. **Dev-CA**: напечатает срок действия `leaf-short` (для Chromium-пиннинга).
5. **Три окна**:
   - `start-edge.bat`   → Go WebTransport-edge (H3/QUIC, `:9443`)
   - `start-server.bat` → Node `transport-wt-edge` (TCP `:8444`)
   - `start-web.bat`    → Angular `ng serve` (`:4300`)

### 3. браузер
- Открой **Яндекс Browser** (или другой Chromium).
- URL: **`http://localhost:4300`**
- Первой операцией будет логин: браузер сам откроет WebTransport-канал к
  `https://127.0.0.1:9443/awp` (IPv4! `localhost` для WebTransport — **запрещено**
  — Chromium требует `127.0.0.1` и сертификат `leaf-short` с коротким сроком).

> **Красный флаг**: если браузер говорит «не удалось подключиться» — это либо
> не запущен один из 3 процессов, либо сертификат `leaf-short/leaf.pem`
> истёк (краткосрочный — по дизайне Chromium). Перегенерируй через
> `webtransport-protobuf-certs` и обнови pin в
> `webtransport-protobuf-angular-web/src/app/app.config.ts` (`LEAF_SHORT_SHA256_HEX`).

---

## Часть 2. Как устроено: WebTransport + Protobuf «в пальцах»

### 2.1. Схема (3 процесса, 3 порта)

```
+----------------+           +----------------------+           +-------------------+
|  Браузер       |  H3/QUIC  |  Go edge (quic-go)   |   TCP     |  Node 24 (бизнес) |
|  (Chromium)    |---------->|  webtransport-go     |---------->|  transport-wt-edge|
+----------------+   :9443   +----------------------+   :8444   +-------------------+
   Angular 22        ← TLS   →   «байт-реле»:        ← TCP     →  Envelope decode  →
   ITransport (SEAM)  pinning    читает 4B+len+       → TCP     →  dispatch        →
                 (serverCert-    Envelope-байты,      → TCP     →  response encode →
                    Hashes)       перекидывает       ← TCP     ←  4B+len+resp      ←
                  + IPv4 127.0.0.1                     (1 stream  (1 TCP conn
                  + leaf-short                        = 1 exchange,
                   (<14 дней)                          request→resp→FIN)
```

**Ключевая идея**: **Node никогда не видит QUIC/H3/TLS**. Node знает только:
«пришёл байтовый TCP-поток, там 4-байтовый length + Envelope, ответь тем же».
**Go edge** знает только: «WebSocket-подобный QUIC-поток с ALPN `h3`, байты от
браузера — перели в TCP, байты от Node — перели в браузер». **Браузер** знает:
«WebTransport, один bidi-поток, один запрос → один ответ».

Все три знают один общий формат — **фрейминг** (см. 2.3). Это и есть **SEAM**
(корневой `AGENTS.md` §7 «плагинная модульность» + `PROTOCOL.md` §2).

### 2.2. Единственный wire-тип: `Envelope`

Все сообщения фрон ↔ бэк — **один** protobuf-тип `common.v1.Envelope`
(`webtransport-protobuf-proto/common/v1/envelope.proto`). У него:

```proto
message Envelope {
  string message_id                 = 1;   // UUID, корреляция req/resp
  google.protobuf.Timestamp sent_at  = 2;   // sender clock
  uint32 protocol_version           = 3;   // 1 = v1

  // Дискриминатор «какое сообщение внутри» — oneof payload:
  oneof payload {
    auth.v1.LoginRequest    login_request    = 100;   // домен auth в блоке 100–199
    auth.v1.LoginResponse   login_response   = 101;
    auth.v1.RegisterRequest register_request = 102;
    auth.v1.RegisterResponse register_response= 103;
    auth.v1.RefreshRequest  refresh_request  = 104;
    auth.v1.RefreshResponse refresh_response = 105;
    auth.v1.LogoutRequest   logout_request   = 106;
    auth.v1.LogoutResponse  logout_response  = 107;
    // future домены — блоки 200–299, 300–399, ... (макс. 2047)
  }
}
```

**Почему so?**
- **Единый формат** — Go edge, Node и браузер все знают один протокол.
- **oneof + domain-блоки** — новое доменное сообщение = новое поле в своём блоке
  (100–199 = auth.v1, далее 200–299 …). Адаптер смотрит `payload.case` и
  диспатчит в зарегистрированный обработчик (SEAM!).
- **Транспортная нейтральность** (`PROTOCOL.md` §1): в `Envelope` **нет**
  ни HTTP-статуса, ни REST-пути, ни WebSocket-close-code. Ошибки — в
  сообщении (`AuthError`), не в канале. Смена транспорта (WebTransport ↔
  HTTP-транспортировка) = смена **плагина**, а не контракта.

### 2.3. Фрейминг байтового потока

Поток — это **надёжный bidirectional** с несколькими Envelope'ами подряд
(или один exchange = пара frame'ов — request + response). Формат:

```
<4 bytes, big-endian, length N> <N bytes, Envelope-protobuf>
```

- Максимальный frame в dev: **64 KiB** (поднимается по мере нужд — см. `PROTOCOL.md`).
- Реализован **трижды** (симуметрично — один формат):
  - `webtransport-protobuf-go-edge/cmd/edge/main.go` — `frame()` / `readFrame()`
  - `webtransport-protobuf-nodejs-server/src/plugins/transport-wt-edge/framing.ts` — `frame()` / `FrameReader`
  - `webtransport-protobuf-angular-web/src/core/transport/web-transport-adapter.ts` — `frame` / `FrameReader`

### 2.4. Exchange = 1 request → 1 response

Модель обмена (единая точка «байты в → байты из»):

| Канал | «Exchange» устроен как |
|---|---|
| **Браузер → Go edge** | 1 WT bidi stream = 1 request → 1 response → FIN |
| **Go edge → Node**    | 1 TCP коннект (open) = 1 request → 1 response → FIN (close) |
| **Node**              | `FrameReader.readFrame()` → `dispatchEnvelope()` → `frame(resp)` + `socket.end()` |

Несколько одновременных WT-stream'ов от разных клиентов = несколько TCP
коннектов к Node (1:1). **Нет head-of-line blocking**: каждый exchange изолирован.

### 2.5. Аутентификация (login → token)

Auth-домен = `webtransport-protobuf-proto/auth/v1/auth.proto`. Четыре операции —
все внутри `Envelope`:

| Операция | Request | Response |
|---|---|---|
| Login | `auth.v1.LoginRequest { email, password }` | `auth.v1.LoginResponse { session \| error }` |
| Register | `auth.v1.RegisterRequest { email, password, display_name }` | `auth.v1.RegisterResponse { session \| error }` |
| Refresh | `auth.v1.RefreshRequest { refresh_token }` | `auth.v1.RefreshResponse { tokens \| error }` |
| Logout | `auth.v1.LogoutRequest { refresh_token }` | `auth.v1.LogoutResponse { success \| error }` |

- **Успех** = `session = (TokenPair { access, refresh, expires_in… } , User)`.
- **Ошибка** = `AuthError { code, message }` с кодом из enums
  (`INVALID_CREDENTIALS`, `EMAIL_TAKEN`, `TOKEN_EXPIRED`, `RATE_LIMITED`, …).
- **Rate-limit** (login): `rate-window` — N неудач на email за окно.

**Важно**: логин — это **тоже** WebTransport (не отдельный HTTP). «Auth-вызов» =
такой же Envelope-обмен, просто домен `auth`. После получения `access_token`
токен живёт в `sessionStorage` (см. `webtransport-protobuf-angular-web/src/core/session/token-store.ts`).

### 2.6. Почему три процесса, а не один

| Запрос | Почему так |
|---|---|
| Почему Go edge, а не чистый Node? | Node v24 **без нативного QUIC**. Go (quic-go / webtransport-go) — единственный проверенный путь для H3/QUIC-слушателя. |
| Почему TCP-реле, а не direct? | «Чистое разделение труда»: Go = только транспортный шов (byte relay), Node = только бизнес (decode → dispatch → encode). Ни один из них не знает о доменах/токенах. |
| Почему `leaf-short`? | **Chromium WebTransport** требует `serverCertificateHashes` (пиннинг). Для pinning-сертификата Chromium принимает только короткоживущие (< ~14 дней) ECDSA P-256-серты. `leaf-short/` — ровно это. |
| Почему `127.0.0.1`, а не `localhost`? | Chromium WebTransport требует IPv4-литерала. `localhost` — **отклоняется** на этапе `serverCertificateHashes`. |
| Почему `Envelope.oneof` + домен-блоки? | Единственный wire-тип, который Go, Node и браузер все знают (SEAM). Новые домены = новые блоки (100–199 auth, 200–299 events…). Адаптер диспатчит по `payload.case` — **нет хардкода маршрутов**. |

### 2.7. SEAM (Single Abstraction Point)

Корневой `AGENTS.md` §7: **каждый компонент — самостоятельный плагин**. Конкретно:

```
[бизнес-слой]
   ↓
[ITRANSPORT — «что умеет»: connect / close / send Envelope / on Envelope]
   ↓
[реализация (сменяемая!)]
   ├─ WebTransportAdapter  (браузер, H3/QUIC)
   └─ WtEdgeTcpTransport   (Node, TCP байты)
```

В браузере это `webtransport-protobuf-angular-web/src/core/transport/`:
- `transport.ts` — интерфейс `ITransport` (SEAM).
- `web-transport-adapter.ts` — реализация на WebTransport API.
- `transport-http.ts` — реализация на plain HTTP/2 (fallback, если нужен dev-модус).

В Node это `webtransport-protobuf-nodejs-server/src/plugins/transport-wt-edge/`:
- `tcp-transport.ts` — реализация `ITransport` на локальном TCP (byte relay).
- `framing.ts` — 4B BE length + Envelope.

**Hot-swap**: в `webtransport-protobuf-angular-web/src/app/app.config.ts` одна
строка `kind: 'webtransport' | 'http'` — и браузер использует другой транспорт,
**но тот же `Envelope`**. В Node — одна строка `AWP_PLUGINS` в `server/.env`:
`transport-wt-edge,auth-store-memory,…` vs `transport-http,auth-store-memory,…`.
Контракт (`Envelope` + auth.v1) не меняется.

### 2.8. Конфигурация (env-переменные)

| Ключ | Дефолт | Где |
|---|---|---|
| `AWP_EDGE_ADDR` | `127.0.0.1:9443` | Go edge |
| `AWP_EDGE_NODE_ADDR` | `127.0.0.1:8444` | Go edge → Node (TCP) |
| `AWP_EDGE_CERT_FILE` | `…/certs/leaf/leaf.pem` | Go edge (browser pin — `leaf-short`) |
| `AWP_EDGE_KEY_FILE` | `…/certs/leaf/leaf.key` | Go edge |
| `AWP_PORT` | `8443` (HTTP-транспортировка) | Node |
| `AWP_WT_EDGE_TCP_PORT` | `8444` (byte-relay от Go) | Node |
| `AWP_PLUGINS` | `transport-wt-edge,auth-store-memory,pwd-scrypt,tokens-hmac,rate-window,auth` | Node (порядок!) |
| `AWP_TOKEN_SECRET` | (пусто = ephemeral, dev) | Node |

Порядок `AWP_PLUGINS` проверяется и при необходимости **пересортировывается**
скриптом `check-plugin-order.ts` (правило `requires`) — до старта `main.ts`.
Два плагина одного типа (например `transport-http` + `transport-wt-edge`) = **FATAL**.

---

## Часть 3. Чеклист «что проверить в браузере»

1. `[Network]`-вкладка → WebTransport к `127.0.0.1:9443`.
2. `WebSocket`-таб (если есть) — **не** ожидается (у нас WebTransport, не WS).
3. В devtools → `Console` — ищи `[WebTransport] connect …` / `[WebTransport] exchange ok`.
4. `Performance` — latency первого response (должен быть < 100 ms на локальном).
5. `Application → Session Storage → awp.token` — после логина: `access_token` + `refresh_token`.
6. `Network` — **нет** отдельного REST-вызова `/v1/exchange` (у нас WebTransport).

## Часть 4. Полезные команды

| Что | Команда |
|---|---|
| Только перезапустить edge | `start-edge.bat` |
| Только перезапустить бек | `start-server.bat` |
| Только перезапустить фронт | `start-web.bat` |
| Сгенерировать protobuf-тип | `cd webtransport-protobuf-angular-web && npm run proto:gen` |
| Проверить синтаксис TS | `cd webtransport-protobuf-nodejs-server && npx tsc --noEmit` |
| Запустить e2e через edge | `cd webtransport-protobuf-nodejs-server && npm run e2e:wt-edge` |
| Прогнать unit-тесты бэка | `cd webtransport-protobuf-nodejs-server && npm test` |
| Переиздать dev-CAs | `cd webtransport-protobuf-certs && node make-certs.mjs --force` |
| Проверить срок `leaf-short` | `openssl x509 -in webtransport-protobuf-certs/leaf-short/leaf.pem -noout -dates` |

## Часть 5. Куда копать (по подрепо)

| Что искать | Где |
|---|---|
| Protobuf-контракт (`Envelope` + `auth.v1`) | `webtransport-protobuf-proto/{common,v1,envelope.proto}` + `auth/v1/auth.proto` |
| Протокольные соглашения (фрейминг, ошибки, версии) | `webtransport-protobuf-proto/PROTOCOL.md` |
| WebTransport-адаптер (браузер) | `webtransport-protobuf-angular-web/src/core/transport/` |
| Плагин `auth` (в браузере) | `webtransport-protobuf-angular-web/src/plugins/auth/` |
| SEAM (интерфейс `ITransport`) | `webtransport-protobuf-angular-web/src/core/transport/transport.ts` |
| TCP-транспорт (Node) | `webtransport-protobuf-nodejs-server/src/plugins/transport-wt-edge/` |
| Фрейминг Node | `webtransport-protobuf-nodejs-server/src/plugins/transport-wt-edge/framing.ts` |
| Go edge (H3/QUIC) | `webtransport-protobuf-go-edge/cmd/edge/main.go` |
| Dev-CAs + leaf + leaf-short | `webtransport-protobuf-certs/{ca,leaf,leaf-short}/` + `make-certs.mjs` |

---

## Конец

Этот файл + `bootstrap.bat` + `README.md` + подрепо-`AGENTS.md` — весь необходимый
«onboarding-контент». Новичку достаточно: клон → `bootstrap.bat` → браузер →
поиграться. Всё остальное — в `AGENTS.md` подрепо, где каждая тема имеет свой
руководитель.
