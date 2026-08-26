# AGENTS.md — angular-webtransport-proto-workspace (корневой роутер)

> **Этот файл — точка входа для ИИ-агента.** Он описывает workspace как целое
> и указывает, в каком `AGENTS.md` подрепо искать специфичные правила по той или
> иной теме. Когда работаешь в конкретном подрепо — **читай и его `AGENTS.md`**.
> Общие (workspace-уровневые) правила живут здесь.

## 0. Структура workspace и роутинг по AGENTS.md

```
angular-webtransport-proto-workspace/   ← git-репо (корень)
├── AGENTS.md   # этот роутер + общие правила
├── .gitignore  # исключает 4 подрепо из корневого repo
├── proto/      # [подрепо #1] protobuf-контракты фронт↔бек (source of truth по типам)
│   └── AGENTS.md
├── web/        # [подрепо #2] Angular-приложение (ng new, git автосоздаётся)
│   └── AGENTS.md
├── server/     # [подрепо #3] Node.js + TypeScript-бэкенд (git вручную)
│   └── AGENTS.md
└── certs/      # [подрепо #4] TLS-сертификаты + генератор (dev-HTTPS/TLS 1.3)
    └── AGENTS.md
```

### Куда смотреть по теме

| Тема / запрос | Где искать |
|---|---|
| Структура workspace, общие правила workspace | **этот файл, §0–§2, §6–§8** |
| Протobuf-контракты, синтаксис `.proto`, `buf lint`, версии, changelog | `proto/AGENTS.md` |
| Протокольные соглашения (фрейминг, datagram-потоки, handshake-auth, версия протока) | `proto/AGENTS.md` + сам `proto/PROTOCOL.md` |
| Angular-приложение (frontend), Taiga UI v5, Signal Forms, компоненты, роутинг, UI | `web/AGENTS.md` |
| WebTransport-клиент (адаптер, backpressure, reconnect, SEAM на фронте) | `web/AGENTS.md` |
| Node-бэкенд (ESM, SEAM, бизнес-логика, transport-адаптер на бэке) | `server/AGENTS.md` |
| WebTransport-edge (quic-go / Caddy с ALPN h3), решение по серверной стороне | `server/AGENTS.md` + `proto/PROTOCOL.md` |
| TLS/сертификаты, `make-certs.mjs`, CA/leaf, SAN, импорт CA в Windows | `certs/AGENTS.md` |
| Протobuf codegen (`buf generate`, `@bufbuild/protobuf`, `protoc-gen-es`) | `web/AGENTS.md` **и** `server/AGENTS.md` (каждый — свой `buf.gen.yaml` → свой `src/proto-generated/`) — плюс `proto/AGENTS.md` для контрактов |
| Стек, окружение хоста (Windows/bash/node/buf/openssl/Яндекс Browser/T:), корпуса документации, общие Guardrails | **этот файл, §2, §6, §7, §8** |

### Правила workspace

- **Корневая папка — git-репо**, но в нём отслеживаются **только корневые файлы**
  (`AGENTS.md`, `.gitignore`, и — по мере накопления — другие workspace-уровневые:
  общие `scripts/`, CI-конфиги, workspace-`README.md`).
- **Четыре подрепо** (`proto/`, `web/`, `server/`, `certs/`) **исключены из корневого repo**
  через `.gitignore` (записи `/proto/`, `/web/`, `/server/`, `/certs/`). Каждое —
  собственный автономный git-репозиторий со своей историей и своим `.git/`.
- **Прямых imports исходников одного подрепо в другой — НЕТ.** Единственная легитимная
  связь — **контракт из `proto/`** (сгенерированный тип/структура). Подрепо не вложены
  друг в друга.
- **Порядок изменений**: изменился обмен → сначала `proto/` → `proto:gen` в `web/` и `server/`
  → правки кода в `web/` и `server/`. **Никогда** не дублировать тип/структуру «вручную»
  в `web/` или `server/` — контракт `proto/` — единственный источник.
- **Корневой remote** может быть другим или отсутствовать; подрепо имеют собственные
  remote. Корневой хранит только workspace-уровневую документацию/скрипты.

## 1. Цель проекта

**Фронтенд на Angular** и **бэкенд на Node.js/TypeScript**, общающиеся по протоколу
**WebTransport** (HTTP/3 / QUIC). Все сообщения, летящие между ними, сериализуются в
**protobuf** по контрактам из `proto/`.

Почему WebTransport (а не WebSocket):
- **надёжные потоки (streams)** — упорядоченные, без head-of-line blocking (потоки QUIC
  независимы);
- **ненадёжные датаграммы (datagrams)** — low-latency сообщения, где «потеря = ок»;
- быстрый handshake (QUIC 0-RTT, TLS встроен), устойчивость к смене сети.

WebTransport — это **транспорт**: поточный / bidirectional / datagram-обмен. Для
классического запрос-ответ, если он нужен, — обычный HTTP рядом.

## 2. Зафиксированный стек (workspace-уровень)

| Слой | Выбор | Примечание |
|---|---|---|
| Фронт | **Angular 22**, zoneless | builder `@angular/build:application`, standalone, OnPush — дефолты v22+, НЕ выставлять явно |
| Формы | **Signal Forms** | нет `ngModel`/`FormGroup`, если нет причины |
| Состояние | **signals** | `signal()`, `computed()`, `effect()` |
| UI-кит | **Taiga UI v5** (`taiga-ui` + `@taiga-ui/cdk`) | secondary entry points, `@maskito/core`, CSS custom properties, **БЕЗ** `@angular/animations` |
| TS (оба кода) | **strict** | **`no` `any`**; при неопределённости — `unknown` + сужение |
| Сеть | **WebTransport** | браузер: Chromium API; сервер — см. `server/AGENTS.md` |
| Protobuf runtime | **`@bufbuild/protobuf`** (protobuf-es) | единый runtime и в браузере, и в Node |
| Protobuf codegen | **Buf v2 + `protoc-gen-es`** (`target=ts`) | **КАНОН**. НЕ `ts-proto`, НЕ `protobufjs` |
| Бэкенд | **Node.js 24 + TypeScript** | ESM (`"type": "module"`), те же TS-правила что у фронте, адаптированные под Node |

> Protobuf-линия **одна** во всём workspace: `@bufbuild/protobuf` + `buf generate` +
> `protoc-gen-es`. Не путать с `protobufjs` (legacy-рантайм) и с `@protobuf-ts/runtime`/
> `ts-proto` (другая кодоген-линия). В этом workspace — **protobuf-es**. Точка.

## 3. Окружение хоста (для всех подрепо)

Факты — не правила, просто реальность окружения. Используй при запуске/сборке/отладке.

- **OS**: Windows 11. `terminal` = **bash (git-bash/MSYS)**, НЕ PowerShell/cmd.
  Для нативных утилит — `C:/Users/...` (forward-slash). MSYS-путь `/c/...` bash понимает,
  но `node`/`git`/`buf`/`protoc` — НЕТ (MSYS auto-convert выключен).
- **Scratch / временные файлы**: **диск `T:`** (RAM-диск, в ОЗУ) — НЕ `%TEMP%`, не `/tmp`.
- **node v24 / npm 11** на хосте. `protoc` глобально (~libprotoc 33). `buf` — через
  `@bufbuild/buf` (devDep), **не** глобально.
- **openssl** — из Git for Windows (git-bash, `/usr/bin/openssl`). Системный
  Windows-OpenSSL НЕ предполагать.
- **Node v24 НЕ имеет нативного QUIC** (`node:quic` не грузится) — ограничение для
  серверной стороны WebTransport (решение — в `server/AGENTS.md`).
- **Браузер для верификации**: **Яндекс Browser** (= Chromium) — **ПЕРВОЙ ОЧЕРЕДЬЮ**,
  не `chrome.exe`/`msedge.exe`. CDP `127.0.0.1:9222`, skill `browser-debug`,
  debug-профиль `browser-harness-profile`. Не `taskkill browser.exe` без фильтра.
- **Taiga UI v5**: secondary entry points, `@maskito/core`, **БЕЗ** `@angular/animations`.

## 4. Документация (каноны) — recall workflow

Не додумывать API protobuf/WebTransport/Angular «из головы» — читать по ссылке:

- **Protobuf**: `C:\Users\oleg\corpora\protobuf\` — `urlmap.txt`, `txt/` (97 стр.),
  `triage.json`, `scripts/bulkread.py`. Recall: (1) `mnemosyne_recall "<функция>"`
  (tag `protobuf-docs`); (2) канон-index; (3) `read_file
  C:\Users\oleg\corpora\protobuf\txt\<slug>.txt` → verbatim.
- **RxJS (7.8.2)**: `C:\Users\oleg\corpora\rxjs\` (174 стр., `urlmap.json`,
  `build_corpus.py`). Recall: `mnemosyne_recall "rxjs <тема>"`; затем
  `read_file C:\Users\oleg\corpora\rxjs\txt\<file>.txt`.
- **WebTransport (spec)**: W3C Candidate Recommendation (Feb 2026), IETF
  `draft-ietf-webtrans-http3`. Recall — `mnemosyne_recall("webtransport <тема>")`.
- **Angular**: `angular.dev/ai/develop-with-ai` (code-gen правила, v22+) +
  `angular.dev/reference/releases` (версии/релизы).
- **Angular v22 docs (корпус)**: `T:\angular-docs\txt\<section>\<page>.html.txt`
  (RAM-диск, 1596 стр.; grep через `search_files path=T:\angular-docs\txt`).

## 5. Общие Guardrails (workspace-уровень)

- ❌ Не смешивать четыре подрепо: не вложенные, не «общий git». Корневой репо — только
  workspace-уровневые файлы; подрепо исключены через `.gitignore`.
- ❌ Не импортировать исходники `web/` из `server/` (или наоборот). Единственная связь —
  `proto/`.
- ❌ Не дублировать контракт (тип/структуру сообщения): источник — `proto/`, артефакт —
  сгенерированный код в `web/` или `server/`.
- ❌ Не генерить protobuf через `ts-proto`/`protobufjs` — только **`buf` + `protoc-gen-es`**.
- ❌ Не редактировать `src/proto-generated/` (в `web/` или `server/`) — чинить через
  `.proto` → `npm run proto:gen`.
- ❌ Не писать `any`. В Angular — не писать `standalone: true`/`OnPush` явно. Не тащить
  `@angular/animations`.
- ❌ Не размазывать транспортные детали по компонентам/фичам — только через SEAM
  (адаптер = единственный носитель детали). Правила SEAM — в `web/AGENTS.md` / `server/AGENTS.md`.
- ❌ Не писать в stream без учёта backpressure. Не дублировать reconnect в нескольких местах.
- ❌ Не поднимать WebTransport-сервер на чистом Node (нет QUIC) — см. `server/AGENTS.md`.
- ❌ Не брать `chrome.exe`/`msedge.exe` для верификации; **Яндекс Browser** первичен.
- ❌ Scratch — не в `%TEMP%`/`/tmp`; **`T:`**.
- ❌ Dev-сертификаты (`certs/`) — не для прода, не под реальные домены, наружу не выставлять.
- ⚠️ Login/credentials/payments — стоп и вопрос пользователю; не угадывать секреты.

## 6. Общие Definition of Done (workspace-уровень)

- [ ] Четыре подрепо на месте: `proto/`, `web/`, `server/`, `certs/` — каждый автономный git-репо.
- [ ] Корневой репо инициализирован; `.gitignore` исключает 4 подрепо из корневого repo.
- [ ] В каждом подрепо — свой `AGENTS.md` со специфичными правилами (см. роутинг, §0).
- [ ] Контракт → Реализация → Потребитель (SEAM) в `web/` и `server/`; адаптер заменяем.
- [ ] `.proto` в `proto/` → `npm run proto:gen` в `web/` и `server/` → `src/proto-generated/`
  синхронизирован, баррел перегенерирован.
- [ ] Фрейминг и транспортные правила зафиксированы в `proto/PROTOCOL.md`; реализованы
  симметрично в обоих адаптерах.
- [ ] Решения по стек/пайплайн/транспорт записаны в Mnemosyne (compact fact), не только в чате.

> Per-репо Definition of Done — в каждом `AGENTS.md` подрепо (§ «Definition of Done»).
