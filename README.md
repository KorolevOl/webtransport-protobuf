# webtransport-protobuf (root)

Корневой reпо хранит **workspace-уровневые** файлы: `AGENTS.md` (роутер),
`.gitignore` и `.gitmodules`. Контентные подрепо живут как **submodule**:

| Path    | Репо (github.com/KorolevOl)                      |
|---------|--------------------------------------------------|
| webtransport-protobuf-proto/  | webtransport-protobuf-proto                      |
| webtransport-protobuf-angular-web/    | webtransport-protobuf-angular-web                |
| webtransport-protobuf-nodejs-server/ | webtransport-protobuf-nodejs-server              |
| webtransport-protobuf-certs/  | webtransport-protobuf-certs                      |
| webtransport-protobuf-go-edge/   | webtransport-protobuf-go-edge                    |

## Как использовать

```bash
git clone --recurse-submodules https://github.com/KorolevOl/webtransport-protobuf
# или, если заклонировали без recurse:
git submodule update --init --recursive
```