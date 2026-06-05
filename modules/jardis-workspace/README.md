# jardis-workspace

## File structure

```text
~/
  <workspace-name>/
    libs/                          # bind-mount to host — persists across destroy
  <workspace-name>.code-workspace  # created on first start; user edits are preserved
  .local/share/code-server/        # code-server settings (in home volume)
  ...                              # everything else lives in the home volume
```

## What persists

| Location | Survives stop/start | Survives destroy |
|----------|--------------------|--------------------|
| `~/<workspace-name>/libs/` | Yes | **Yes** — stored on the host |
| `~/` (home volume) | Yes | No |

`libs/` is the only directory shared with the host. Everything else (shell history, editor settings, uncommitted files outside `libs/`) is in a private Docker volume that is deleted when the workspace is destroyed.

## Workspace lifecycle

### On every start

1. `code-server` is installed (standalone, under `/tmp/code-server/`).
2. The jardis extension is downloaded from the private GitHub release and installed — only when the version changes.
3. The `ibmi-languages` extension is installed from Open VSX.
4. Repos are cloned into `~/<workspace-name>/libs/` — repos already present are skipped.
5. Jardis settings (`host`, `port`, `env`, `user`) are merged into `~/.local/share/code-server/User/settings.json` — admin changes to these values take effect on the next start without destroying the workspace.
6. `code-server` starts (owner-only access proxied through the Coder dashboard).

### On first start only

The `.code-workspace` file is created at `~/<workspace-name>.code-workspace` with:
- a folder entry for each repo under `libs/`
- Jardis `attach` and `run` launch configurations

If the file already exists it is left untouched, so any edits you make are preserved across restarts.

### On stop

The container is stopped. The home volume and `libs/` are untouched.

### On destroy

The home volume is deleted. `libs/` on the host is **not** deleted — repos survive and will not be re-cloned when a new workspace is created.
