# smeuperp workspace

Coder workspace for SMEUP ERP development — code-server (VS Code in the browser) with the jardis extension and the smeup private repos pre-cloned.

## Workspace lifecycle

### First start

When you create a workspace for the first time:

1. A Docker image is built from the template (takes a few minutes).
2. A **persistent home volume** is created and mounted at `~` — this is where your personal files live.
3. The **jardis** extension is downloaded from the private `smeup/jardis` release and installed into code-server.
4. The following repos are cloned into `~/smeuperp/libs/`:
   ```
   kokos-dsl-smeuperp
   kokos-dsl-smeuperp-custom
   kokos-dsl-smeuperp-persup
   kokos-dsl-smeuperp-smeupdem
   ```
5. Jardis extension settings (`host`, `port`, `user`, `env`) are written to `~/.local/share/code-server/User/settings.json`.
6. A `smeuperp.code-workspace` file is created in `~/smeuperp/` pointing to the four library repos.
7. code-server starts and opens `~/smeuperp/smeuperp.code-workspace` as a multi-root workspace.

### Stop → Start

Stopping a workspace shuts down the container but **preserves all your files**. On next start:

- Your home directory, git history, and local changes are exactly as you left them.
- Repos are not re-cloned (they are already in `~/smeuperp/libs/`).
- The jardis extension is not reinstalled unless the version has been updated by the template admin.

**Always stop rather than delete your workspace when you are done for the day.**

### Destroying a workspace

> ⚠️ **Destroying a workspace permanently deletes your home volume.**

The following are **lost**:

- Uncommitted changes in any repo
- Files you created outside of `~/smeuperp/libs/`
- Shell history, editor settings, and any local configuration

The following **survive** destruction because they live on the host filesystem:

- The cloned repos in `~/smeuperp/libs/` — recreating the workspace will find them already there and skip cloning

Before destroying, make sure to **commit and push** any work you want to keep.

### Template updates

When the template admin pushes a new version, your workspace shows an **Update** button. Applying an update:

- Rebuilds the Docker image if `build/` changed (e.g. a new bundled extension).
- **Does not delete your home volume** — your files and repos are preserved.
- Restarts the workspace so the new image takes effect.

> Jardis host/port changes take effect on the next workspace start — no need to destroy the workspace.

## Jardis extension settings

On every workspace start, the following settings are injected into `~/.local/share/code-server/User/settings.json`:

```json
{
    "jardis.user": "<your-coder-username>",
    "jardis.host": "<configured-by-admin>",
    "jardis.port": "<configured-by-admin>",
    "jardis.env": "smeuperp-user"
}
```

These values come from the server configuration — you do not need to set them manually. Because they are re-applied on every start, any admin change to `host` or `port` takes effect automatically on next restart.

## GitHub authentication

On first workspace creation, Coder asks you to **Connect GitHub**. This one-time step grants the workspace access to your GitHub account to clone the private repos and download the jardis extension. You will not be prompted again for subsequent workspaces.

If the workspace loses access to GitHub (e.g. token expired), go to **Coder UI → top-right avatar → Account → External Auth** and reconnect GitHub.
