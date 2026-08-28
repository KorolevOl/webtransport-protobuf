# angular-webtransport-workspace (root)

Корневой reпо хранит **workspace-уровневые** файлы: `AGENTS.md` (роутер),
`.gitignore` и `.gitmodules`. Контентные подрепо живут как **submodule**:

| Path | Репо (github.com/KorolevOl) |
|------|------------------------------|
| proto/  | angular-webtransport-proto     |
| web/    | angular-webtransport-web       |
| server/ | angular-webtransport-server    |
| certs/  | angular-webtransport-certs     |
| edge/   | angular-webtransport-edge      |

## Как использовать

```bash
git clone --recurse-submodules https://github.com/KorolevOl/angular-webtransport
# или, если заклонировали без recurse:
git submodule update --init --recursive
```
