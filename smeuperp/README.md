# smeuperp workspace

Coder workspace for SMEUP ERP development — code-server (VS Code in the browser) with the jardis extension and the smeup private repos pre-cloned.

## Workspace lifecycle

### First start

When you create a workspace for the first time:

1. A Docker image is built from the template (takes a few minutes).
2. A **persistent home volume** is created and mounted at `~` — this is where all your files live.
3. The **jardis** extension is downloaded from the private `smeup/jardis` release and installed into code-server.
4. The following repos are cloned into `~/libs/`:
   ```
   kokos-dsl-smeuperp
   kokos-dsl-smeuperp-custom
   kokos-dsl-smeuperp-persup
   kokos-dsl-smeuperp-smeupdem
   ```
5. code-server starts and the browser opens your workspace.

### Stop → Start

Stopping a workspace shuts down the container but **preserves the home volume**. On next start:

- Your files, git history, and any local changes are exactly as you left them.
- Repos are not re-cloned (the `~/libs/` directories already exist).
- The jardis extension is not reinstalled unless the version has been updated by the template admin.

**Always stop rather than delete your workspace when you are done for the day.**

### Destroying a workspace

> ⚠️ **Destroying a workspace permanently deletes your home volume.**

Everything stored in `~` is lost, including:

- Uncommitted changes in any repo
- Files you created or downloaded in the home directory
- Shell history, editor settings, and any local configuration

Before destroying, make sure to **commit and push** all work you want to keep.

### Template updates

When the template admin pushes a new version, your workspace shows an **Update** button. Applying an update:

- Rebuilds the Docker image if `build/` changed (e.g. a new bundled extension).
- **Does not delete your home volume** — your files and repos are preserved.
- Restarts the workspace so the new image takes effect.

## GitHub authentication

On first workspace creation, Coder asks you to **Connect GitHub**. This one-time step grants the workspace access to your GitHub account to clone the private repos and download the jardis extension. You will not be prompted again for subsequent workspaces.

If the workspace loses access to GitHub (e.g. token expired), go to **Coder UI → top-right avatar → Account → External Auth** and reconnect GitHub.
