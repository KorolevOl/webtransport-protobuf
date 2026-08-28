# webtransport-protobuf (root)

Корневой reпо хранит **workspace-уровневые** файлы: `AGENTS.md` (роутер),
`.gitignore` и `.gitmodules`. Пять контентных подрепо — **git-submodule'ы**;
имена папок совпадают с именами репо (список — в `.gitmodules`).

**Папки подрепо** (все `github.com/KorolevOl/...`, ветка `master`):
- `webtransport-protobuf-proto` — protobuf-контракты
- `webtransport-protobuf-angular-web` — фронт на Angular 22
- `webtransport-protobuf-nodejs-server` — бек на Node.js 24
- `webtransport-protobuf-certs` — dev-TLS (CA + leaf)
- `webtransport-protobuf-go-edge` — WebTransport-edge (H3/QUIC, Go)

## Как использовать

```bash
git clone --recurse-submodules https://github.com/KorolevOl/webtransport-protobuf
# или, если заклонировали без recurse:
git submodule update --init --recursive
```