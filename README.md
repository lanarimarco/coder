# Coder – jardis workspace infrastructure

Self-hosted [Coder](https://coder.com) instance for jardis-based development workspaces, running on Docker Compose.

## Architecture

```
docker-compose.yml          # Coder server + PostgreSQL
.env                        # Secrets (gitignored — see .env.template)
push-template.sh            # Helper to push any template (dereferences symlinks)
new-template.sh             # Scaffold a new template directory
modules/
  jardis-workspace/         # Shared Terraform module — all workspace logic lives here
    main.tf
    variables.tf
    build/
      Dockerfile
<template-name>/            # One directory per workspace template
  main.tf                   # Thin caller: providers + module block with template values
  modules -> ../modules     # Symlink so terraform init resolves the module locally
```

All workspace logic (startup script, Docker image, code-server setup) lives in `modules/jardis-workspace/` and is reused by every template. Only the five values in the `module "workspace"` block differ between templates.

## Server setup

### 1. Prepare the host

Create the shared workspace directory on the host. Each user's workspace will bind-mount its own subdirectory from here. The base path is set via `users_workspace_path` in the `module "workspace"` block of the template's `main.tf` (default: `/home/kokos/users-workspace`).

```bash
sudo mkdir -p /home/kokos/users-workspace
sudo chmod 777 /home/kokos/users-workspace
```

> **macOS / Docker Desktop only:** Docker Desktop restricts which host paths can be bind-mounted into containers. Add the base directory to the allowed list before starting workspaces:
> **Docker Desktop → Settings → Resources → File Sharing → add the path → Apply & Restart**
>
> On Linux this restriction does not exist.

### 2. Configure secrets

```bash
cp .env.template .env
```

Fill in `.env` with the GitHub OAuth App credentials (see section below).

### 3. Start the stack

```bash
docker compose up -d
```

Coder is available at `http://localhost:7080`.

### 4. Create the first admin user

Open `http://localhost:7080` and complete the initial setup wizard.

---

## How workspace files are exposed to other processes

### What lives where

| Path | Visible to | Persists across workspace destroy? |
|------|-----------|-----------------------------------|
| `~/` (home volume) | workspace only | No |
| `~/<template-name>/libs` | workspace + host | Yes |

### `~/<template-name>/libs` — the per-user libs directory

When a workspace starts, repos are cloned into `$USERS_WORKSPACE_PATH/<username>/libs/` on the **host filesystem**. Inside the container, only `$USERS_WORKSPACE_PATH/<username>/libs` is bind-mounted — other users' directories are never visible from within the workspace. `~/<template-name>/libs` is a symlink to that host path.

- **From the host**: files are at `$USERS_WORKSPACE_PATH/<username>/libs/`
- **From an external container**: mount `$USERS_WORKSPACE_PATH` to access all users' repos, each under their own subdirectory
- **Survives workspace destruction**: the files live on the host, not in the home Docker volume. Recreating the workspace skips cloning since the repos are already there

### Mounting libs in an external container

Replace `$USERS_WORKSPACE_PATH` with the value of `users_workspace_path` in the template's `main.tf` (default `/home/kokos/users-workspace`):

```yaml
services:
  myapp:
    image: myapp:latest
    volumes:
      - /home/kokos/users-workspace:/workspace-libs:ro
```

Each user's repos are then at `/workspace-libs/<coder-username>/<repo-name>` etc.

### `~/` — the private home volume

Everything else (shell history, editor config, uncommitted files outside libs) lives in a Docker named volume private to that workspace. It is **not** accessible from the host or other containers, and is **deleted when the workspace is destroyed**.

---

## Jardis service configuration

The Jardis host, port, and environment are injected into the code-server user settings (`~/.local/share/code-server/User/settings.json`) on **every** workspace start, so they always reflect the current template values.

Edit the values in the `module "workspace"` block of `<template-name>/main.tf`:

```hcl
module "workspace" {
  source = "./modules/jardis-workspace"

  jardis_host = "localhost"       # ← change this
  jardis_port = 9091              # ← change this
  jardis_env  = "my-env-user"    # ← change this
  ...
}
```

Then push the template:

```bash
./push-template.sh <template-name>
```

On the next workspace start, the startup script merges these values into the user settings file:

```json
{
    "jardis.user": "<coder-username>",
    "jardis.host": "<jardis_host>",
    "jardis.port": <jardis_port>,
    "jardis.env": "<jardis_env>"
}
```

Because settings are re-applied on every start, pushing the template and stopping/starting the workspace is enough to pick up new values.

---

## GitHub OAuth Apps

Two separate OAuth Apps are required because each uses a different callback URL.

| App name | Callback URL | Purpose |
|----------|-------------|---------|
| `coder-login` | `http://<host>:7080/api/v2/users/oauth2/github/callback` | "Sign in with GitHub" on the Coder login page |
| `coder-external` | `http://<host>:7080/external-auth/github/callback` | Workspace template access to private repos and release assets |

Create each at **GitHub → Settings → Developer settings → OAuth Apps → New OAuth App**.

### Approving both apps for the `smeup` org

The `smeup` org restricts third-party OAuth App access. Each app must be approved by an org admin before it can access private org resources.

**Approval flow (repeat for each app):**

1. Sign in to Coder with the app (login app) or create a workspace (external app) — this triggers the org access block
2. Go to **GitHub → Settings → Applications → Authorized OAuth Apps**, click the app, click **Request access** next to `smeup`
3. As org admin, go to `https://github.com/organizations/smeup/settings/oauth_application_policy` and approve it

---

## Managing templates

### Creating a new template

```bash
./new-template.sh <template-name>
```

> `<template-name>` should match the kokos application name (e.g. `smeuperp`, `demo`).

The script prompts for the required values and scaffolds a new template directory:

```
Creating template 'demo'

jardis_host                              : 192.168.1.10
jardis_port                              : 9091
jardis_env           [demo-user]: 
users_workspace_path [/home/kokos/users-workspace]: 

Enter repo names one per line (empty line to finish):
  repo: kokos-dsl-showcase
  repo:

Template 'demo' created:
  demo/main.tf
  demo/modules -> ../modules  (symlink)
```

Review the generated `<template-name>/main.tf`, then push with `./push-template.sh <template-name>`.

### Install the Coder CLI

Skip this step if `coder` is already installed (`coder version` to check).

```bash
curl -fsSL https://coder.com/install.sh | sh
```

Then log in against your Coder instance:

```bash
coder login http://localhost:7080
```

### Push a template version

```bash
./push-template.sh <template-name>
```

> The script uses `cp -rL` to dereference the `<template-name>/modules` symlink before uploading, because Coder's provisioner does not follow symlinks.

### What requires workspace destroy vs. stop/start

| Change | Stop/start enough? |
|--------|-------------------|
| Jardis extension version | Yes |
| ibmi-languages extension | Yes (reinstalled on every start) |
| `jardis_host` / `jardis_port` / `jardis_env` in `main.tf` | Push template, then stop/start |
| `users_workspace_path` in `main.tf` | No — destroy and recreate (also restart docker-compose) |
| Bind mount path changes | No — destroy and recreate |
| Repo list changes | Yes (new repos are cloned on next start) |

### Updating the jardis extension

Edit `JARDIS_VERSION` and `JARDIS_VSIX` in `modules/jardis-workspace/main.tf`, then push the template. Existing workspaces pick up the new version on next start.

---

## Upgrading Coder

Change the image tag in `docker-compose.yml` and restart:

```bash
docker compose up -d
```
