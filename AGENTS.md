# AGENTS.md — angular-webtransport-proto-workspace (корневой роутер)

> **Этот файл — точка входа для ИИ-агента.** Он описывает workspace как целое
> и указывает, в каком `AGENTS.md` подрепо искать специфичные правила по той или
> иной теме. Когда работаешь в конкретном подрепо — **читай и его `AGENTS.md`**.
> Общие (workspace-уровневые) правила живут здесь.

## 🚪 Быстрый навигатор по AGENTS.md подрепо

| Подрепо | AGENTS.md подрепо | О чём |
|---|---|---|
| `proto/` | [proto/AGENTS.md](proto/AGENTS.md) | Protobuf-контракты, `buf.yaml`, стиль `.proto`, `PROTOCOL.md`, версии |
| `web/`  | [web/AGENTS.md](web/AGENTS.md)  | Angular 22, Taiga UI, SEAM, WebTransport-клиент, codegen, верификация |
| `server/` | [server/AGENTS.md](server/AGENTS.md) | Node 24 + TS strict, SEAM, WebTransport-edge (quic-go/Caddy), ESM |
| `certs/` | [certs/AGENTS.md](certs/AGENTS.md) | Dev TLS: dev-CA + leaf (SAN localhost/127.0.0.1), `make-certs.mjs`, импорт CA |

> Каждый подрепо-`AGENTS.md` **самостоятелен**: он ссылается на этот (`../AGENTS.md`)
> для общих workspace-правил и содержит только специфику именно своего подрепо.

## 0. Структура workspace и роутинг по AGENTS.md

```
angular-webtransport-proto-workspace/   ← git-репо (корень)
├── AGENTS.md   # этот роутер + общие правила
├── .gitignore  # исключает 4 подрепо из корневого repo
├── proto/      # [подрепо #1] protobuf-контракты фронт↔бек (source of truth по типам)
│   └── AGENTS.md
├── web/        # [подрепо #2] Angular-приложение
│   └── AGENTS.md
├── server/     # [подрепо #3] Node.js + TypeScript-бэкенд
│   └── AGENTS.md
└── certs/      # [подрепо #4] TLS-сертификаты + генератор (dev-HTTPS/TLS 1.3)
    └── AGENTS.md
```

### Куда смотреть по теме

| Тема / запрос | Где искать |
|---|---|
| Структура workspace, общие правила workspace | **этот файл, §0–§7** |
| Protobuf-контракты, синтаксис `.proto`, `buf lint`, версии, changelog | [proto/AGENTS.md](proto/AGENTS.md) |
| Протокольные соглашения (фрейминг, datagram-потоки, handshake-auth, версия протока) | [proto/AGENTS.md](proto/AGENTS.md) + сам [proto/PROTOCOL.md](proto/PROTOCOL.md) |
| Angular-приложение (frontend), Taiga UI v5, Signal Forms, компоненты, роутинг, UI | [web/AGENTS.md](web/AGENTS.md) |
| WebTransport-клиент (адаптер, backpressure, reconnect, SEAM на фронте) | [web/AGENTS.md](web/AGENTS.md) |
| Node-бэкенд (ESM, SEAM, бизнес-логика, transport-адаптер на бэке) | [server/AGENTS.md](server/AGENTS.md) |
| WebTransport-edge (quic-go / Caddy с ALPN h3), решение по серверной стороне | [server/AGENTS.md](server/AGENTS.md) + [proto/PROTOCOL.md](proto/PROTOCOL.md) |
| TLS/сертификаты, `make-certs.mjs`, CA/leaf, SAN, импорт CA в Windows | [certs/AGENTS.md](certs/AGENTS.md) |
| Protobuf codegen (`buf generate`, `@bufbuild/protobuf`, `protoc-gen-es`) | [web/AGENTS.md](web/AGENTS.md) **и** [server/AGENTS.md](server/AGENTS.md) (каждый — свой `buf.gen.yaml` → свой `src/proto-generated/`) — плюс [proto/AGENTS.md](proto/AGENTS.md) для контрактов |
| Стек (§2), окружение хоста (§3), корпуса документации (§4), общие Guardrails (§5), DoD (§6), dev-правила + архитектура-плагинность (§7) | **этот файл, §2–§7** |

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

WebTransport — это **транспорт**: поточный / bidirectional / datagram-обмен.

### Модель взаимодействия фрон ↔ бэк

**Все** взаимодействия фронта и бэка идут **исключительно через WebTransport**, за исключением
двух категорий, которые остаются на обычном HTTP:

1. **Логин / Регистрация / Авторизация** (обмен токеном) — классический HTTP-запрос.
2. **Получение токена** — HTTP-запрос (response содержит token).

**После получения токена** всё остальное — **только** WebTransport:

| Тип обмена | Транспорт | Реализация |
|---|---|---|
| **События** (push от сервера, без ожидания response) | WebTransport | датаграммы (ненадёжные) или stream (надёжные) — по смыслу события |
| **Акции без ожидания ответа** (fire-and-forget) | WebTransport | датаграммы (ненадёжные) — «потеряло = ок»; если надёжность нужна — stream |
| **Запрос-ответ** (аналог GET/POST; ждём response) | WebTransport | **надёжный bidirectional stream**: клиент пишет request → ждёт response в том же потоке; сервер обрабатывает → отвечает в том же потоке → закрывает |

> **Нет** отдельного HTTP-канала для «обычного REST». Все бизнес-запросы/ответы —
> **через WebTransport stream**, сериализованные protobuf по контрактам `proto/`.

**Нетокен = редирект на логин.** Если клиент не имеет валидного токена:
1. Запомнить текущий URL (запрос, на который был ответ 401/403, или текущая маршрутная
   строка) — в **`sessionStorage`** (не `localStorage`, не переживает закрытие вкладки).
   Источник — один, правило реализации — в [web/AGENTS.md](web/AGENTS.md) «Токен и редирект».
2. Перенаправить на страницу логина/авторизации (HTTP-форма).
3. После успешной авторизации — **вернуться** на запомненный URL.

### Живой цикл WebTransport (singleton)

**Один** WebTransport-канал на всё приложение, пока оно живо. Не «на фичу», не «на
запрос» — **один общий**, установленный один раз после успешной авторизации, и живёт
пока приложение не завершит работу.

| Событие | Действие |
|---|---|
| Успешная авторизация (получен токен) | **Установить** WebTransport (один раз, singleton). |
| Долгая неактивность (idle timeout — см. `PROTOCOL.md`) | **Разорвать** WebTransport. Запомнить токен (ещё живой). |
| Возобновление активности + токен жив | **Переподключить** WebTransport (автоматически, не спрашивая). |
| Возобновление активности + токен истёк | **Редирект на логин** (см. выше). |
| Закрытие приложения (`window.close`, `beforeunload`, logout) | **Разорвать** WebTransport (graceful close). |
| Сервер разоряет (401, 5xx, network loss) | Запомнить статус. При следующем действии — по таблице выше. |

> **НЕ** поднимать второй WebTransport рядом с первым (даже ради «отдельного канала
> для событий»). Всё через один: streams — для запрос-ответ и надёжных событий,
> datagrams — для fire-and-forget. Фрейминг многих сообщений в одном потоке — из
> `proto/PROTOCOL.md`.

> Реализация — в едином адаптере **SEAM** ([web/AGENTS.md](web/AGENTS.md)
> «WebTransport-клиент»: singleton + `connect`/`close`/`reconnect`, не дублировать в
> компонентах) и в `server/` (один listener, не один на запрос). Подробности
> idle-таймаута и reconnect-backoff — в `proto/PROTOCOL.md`.

> Детали (формат токена, где хранить, какой срок жизни, refresh-политика) — фиксируются
> в `proto/PROTOCOL.md`. Правила реализации редиректа — в [web/AGENTS.md](web/AGENTS.md);
> правила выдачи/проверки токена — в [server/AGENTS.md](server/AGENTS.md).

## 2. Зафиксированный стек (workspace-уровень)

| Слой | Выбор | Примечание |
|---|---|---|
| Фронт | **Angular 22**, zoneless | builder `@angular/build:application`, standalone, OnPush — дефолты v22+, НЕ выставлять явно |
| Формы | **Signal Forms** | нет `ngModel`/`FormGroup`, если нет причины |
| Состояние | **signals** | `signal()`, `computed()`, `effect()` |
| UI-кит | **Taiga UI v5** (`taiga-ui` + `@taiga-ui/cdk`) | secondary entry points, `@maskito/core`, CSS custom properties, **БЕЗ** `@angular/animations` |
| TS (оба кода) | **strict** | **`no` `any`**; при неопределённости — `unknown` + сужение |
| Сеть | **WebTransport** | браузер: Chromium API; сервер — см. [server/AGENTS.md](server/AGENTS.md) |
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
  серверной стороны WebTransport (решение — в [server/AGENTS.md](server/AGENTS.md)).
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
  (адаптер = единственный носитель детали). Правила SEAM — в [web/AGENTS.md](web/AGENTS.md) /
  [server/AGENTS.md](server/AGENTS.md).
- ❌ Не монолитить: каждый компонент — **самостоятельный плагин** (подключается /
  заменяется / отключается). Канон — §7 «Архитектура: плагинная модульность».
- ❌ Не поднимать WebTransport-сервер на чистом Node (нет QUIC) — см. [server/AGENTS.md](server/AGENTS.md).
- ❌ Не брать `chrome.exe`/`msedge.exe` для верификации; **Яндекс Browser** первичен.
- ❌ Scratch — не в `%TEMP%`/`/tmp`; **`T:`**.
- ❌ Dev-сертификаты (`certs/`) — не для прода, не под реальные домены, наружу не выставлять.
- ⚠️ Login/credentials/payments — стоп и вопрос пользователю; не угадывать секреты.

## 6. Общие Definition of Done (workspace-уровень)

- [ ] Четыре подрепо на месте: `proto/`, `web/`, `server/`, `certs/` — каждый автономный git-репо.
- [ ] Корневой репо инициализирован; `.gitignore` исключает 4 подрепо из корневого repo.
- [ ] В каждом подрепо — свой `AGENTS.md` со специфичными правилами (см. роутинг, §0).
- [ ] Контракт → Реализация → Потребитель (SEAM) в `web/` и `server/`; адаптер заменяем.
- [ ] Плагинная модульность (§7): каждый компонент — самостоятельный плагин (подключается /
  заменяется / отключается); ни одно правило выше не нарушает это — DI/реестр, не моноклассы.
- [ ] `.proto` в `proto/` → `npm run proto:gen` в `web/` и `server/` → `src/proto-generated/`
  синхронизирован, баррел перегенерирован.
- [ ] Фрейминг и транспортные правила зафиксированы в `proto/PROTOCOL.md`; реализованы
  симметрично в обоих адаптерах.
- [ ] Решения по стек/пайплайн/транспорт записаны в Mnemosyne (compact fact), не только в чате.

> Per-репо Definition of Done — в каждом подрепо:
> [proto/AGENTS.md](proto/AGENTS.md) · [web/AGENTS.md](web/AGENTS.md) · [server/AGENTS.md](server/AGENTS.md) · [certs/AGENTS.md](certs/AGENTS.md)
> (раздел «Definition of Done»).

## 7. Общие правила разработки (применяются к `web/` и `server/`)

> **Единый источник для общих dev-правил — этот раздел.** Подрепо не повторяют его,
> а ссылаются (`корневой §7`) и содержат только то, что специфично именно для них.
> Это устраняет дублирование между [web/AGENTS.md](web/AGENTS.md) и [server/AGENTS.md](server/AGENTS.md).

### Архитектура: плагинная модульность (оба кода)
Вся программа строится **как набор самостоятельных плагинов**: каждый компонент
(фича, сервис, адаптер, use-case) — автономный модуль, который **свободно подключается,
заменяется и отключается** без правки остального кода. Это тот же принцип
**Контракт → Реализация → Потребитель** (SEAM), но применённый к **всем**
компонентам программы, а не только к транспортному шву.

Критерий «самостоятельный плагин»:
- **Контракт + реализация** — снаружи доступен только контракт («что умеет»);
  реализация («как умеет») — заменяемая.
- **Подключение через реестр, не через прямые `import`** — компонент вешается и снимается
  в единой точке (реестр / массив / DI-providers), а не хардкодом в чужом коде.
- **Никаких прямых imports одного компонента в другой** — взаимодействие только через
  контракт / DI. Замена = смена записи в реестре, а не перекомпиляция половины мира.
- **Свой lifecycle и teardown** — подключение и отключение не оставляют висячих
  ресурсов (подписки, таймеры, соединения); cleanup — обязанность плагина.
- **Горячая замена (hot-swap)** — при живом контексте и неизменном контракте реализация
  одного плагина меняется без остановки всего приложения.

Механика (кандидат, детализируется при реализации):
- `web/` — DI Angular (providers + injectables) + реестр фич: подключаешь/отключаешь
  фичу в provider-списке; адаптер транспорта — сам такой плагин (SEAM).
- `server/` — DI (ручной сбор или контейнер, напр. `tsyringe`) + реестр use-case'ов /
  обработчиков: подключение = запись в реестр, отключение = снятие записи; адаптер — плагин (SEAM).

> Не противоречит §1 (singleton WebTransport): **транспорт** остаётся один,
> плагинными являются **компоненты над ним** — фичи / сервисы / адаптеры.

### Стиль TypeScript (оба кода)
- **strict** — включён; конкретные strict-флаги — в `tsconfig.json` каждого подрепо.
- **`no` `any`** — при неопределённости: `unknown` + narrowing, а не `any`.
- Имена файлов — **дефисы** (кебаб-кейс): `user-profile.component.ts`, `message-router.ts`.
- **БЕЗ** `helpers.ts` / `utils.ts` / `common.ts` — одна концепция = один модуль.

### Protobuf codegen (оба кода) — канон
- Runtime: **`@bufbuild/protobuf`** (protobuf-es). **Запрещены** `ts-proto`, `protobufjs`,
  `@protobuf-ts/runtime` (см. §2, §5).
- `buf.gen.yaml` (v2, **содержимое одинаковое** в обоих, но у каждого репо **свой физический файл**):
  ```yaml
  version: v2
  plugins:
    - local: protoc-gen-es
      out: src/proto-generated
      opt:
        - target=ts
        - import_extension=none
        # - json_types=true   # если нужен JSON-mapping
  ```
- Скрипт в `package.json` (оба):
  `proto:gen` = `node scripts/clean-proto.js && buf generate ../proto && node scripts/generate-proto-index.js`
- Зависимости: runtime `@bufbuild/protobuf`; dev `@bufbuild/buf`, `@bufbuild/protoc-gen-es`.
- `src/proto-generated/` — **вывод кодогена, никогда не редактировать** (чинить через `.proto`).

### Логирование (оба кода)
- **ОДИН logger-фасад**; все логи — только через него.
- Лог **обязателен** на: вход/выход функций, ветвления решений, внеш. операции (сеть/диск/
  subprocess), обработку ошибок, переходы состояний.
- Конкретная библиотека — за подрепо (`web/`: candidate `@taiga-ui/kit-logging` или свой слой;
  `server/`: candidate `pino`).
