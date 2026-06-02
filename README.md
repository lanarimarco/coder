# Coder – smeuperp infrastructure

Self-hosted [Coder](https://coder.com) instance for SMEUP ERP development, running on Docker Compose.

## Architecture

```
docker-compose.yml       # Coder server + PostgreSQL
.env                     # Secrets (gitignored — see .env.template)
smeuperp/                # Workspace template for smeuperp developers
  main.tf                # Terraform template
  build/
    Dockerfile
```

## Server setup

### 1. Prepare the host

Create the shared libs directory on the host. Each user's workspace will bind-mount its own subdirectory from here. The base path defaults to `/home/kokos/users-workspace` and can be overridden with `USERS_WORKSPACE_PATH` in your `.env`.

```bash
sudo mkdir -p /home/kokos/users-workspace
sudo chmod 777 /home/kokos/users-workspace
```

> **macOS / Docker Desktop only:** Docker Desktop restricts which host paths can be bind-mounted into containers. Add the base directory (e.g. `/home/kokos/users-workspace`) to the allowed list before starting workspaces:
> **Docker Desktop → Settings → Resources → File Sharing → add the path → Apply & Restart**
>
> On Linux this restriction does not exist.

### 2. Configure secrets

```bash
cp .env.template .env
```

Fill in `.env` with the GitHub OAuth App credentials and the Jardis service coordinates (see sections below).

### 3. Start the stack

```bash
docker compose up -d
```

Coder is available at `http://localhost:7080`.

### 4. Create the first admin user

Open `http://localhost:7080` and complete the initial setup wizard.

---

## How workspace files are exposed to other processes

This is a key aspect of the setup.

### What lives where

| Path | Visible to | Persists across workspace destroy? |
|------|-----------|-----------------------------------|
| `~/` (home volume) | workspace only | No |
| `~/smeuperp/libs` | workspace + host | Yes |

### `~/smeuperp/libs` — the per-user libs directory

When a workspace starts, repos are cloned into `$USERS_WORKSPACE_PATH/<username>/libs/` on the **host filesystem** (e.g. `/home/kokos/users-workspace/admin/libs/`). Inside the container, `$USERS_WORKSPACE_PATH` is bind-mounted to that user-specific libs subdirectory only — other users' directories are never visible from within the workspace. `~/smeuperp/libs` is a symlink to `$USERS_WORKSPACE_PATH`.

- **From the host**: files are at `$USERS_WORKSPACE_PATH/<username>/libs/` (e.g. `/home/kokos/users-workspace/admin/libs/`)
- **From an external container**: mount `$USERS_WORKSPACE_PATH` to access all users' repos, each under their own subdirectory
- **Survives workspace destruction**: the files live on the host, not in the home Docker volume. Recreating the workspace skips cloning since the repos are already there

### Mounting libs in an external container

Replace `$USERS_WORKSPACE_PATH` with the actual value from your `.env` (default `/home/kokos/users-workspace`):

```yaml
services:
  myapp:
    image: myapp:latest
    volumes:
      - /home/kokos/users-workspace:/smeuperp-libs:ro
```

Each user's repos are then at `/smeuperp-libs/<coder-username>/kokos-dsl-smeuperp` etc.

### `~/` — the private home volume

Everything else (shell history, editor config, uncommitted files outside libs) lives in a Docker named volume private to that workspace. It is **not** accessible from the host or other containers, and is **deleted when the workspace is destroyed**.

---

## Jardis service configuration

The Jardis host and port are written into the `smeuperp.code-workspace` VS Code settings automatically on each workspace start.

Set them in `.env`:

```env
JARDIS_HOST=your_jardis_host_here
JARDIS_PORT=your_jardis_port_here
```

These values flow from `.env` → `docker-compose.yml` (as `TF_VAR_jardis_host` / `TF_VAR_jardis_port`) → Coder's Terraform provisioner, which writes a `.jardis.env` file into the user's workspace directory at workspace creation time. The startup script sources this file and writes it into `smeuperp.code-workspace`:

```json
"settings": {
    "jardis.user": "<coder-username>",
    "jardis.host": "<JARDIS_HOST>",
    "jardis.port": <JARDIS_PORT>,
    "jardis.env": "smeuperp"
}
```

The workspace file is created once on first start from the values in `.jardis.env` and is not overwritten on subsequent starts, so user edits are preserved. The `.jardis.env` file itself is only (re)written when the workspace is created, so changing `.env` values requires destroying and recreating the workspace.

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

## Managing the smeuperp template

### Install the Coder CLI

```bash
curl -fsSL https://coder.com/install.sh | sh
```

Then log in against your Coder instance:

```bash
coder login http://localhost:7080
```

### Push a new version

```bash
coder template push smeuperp --directory smeuperp/
```

### What requires workspace destroy vs. stop/start

| Change | Stop/start enough? |
|--------|-------------------|
| Jardis extension version | Yes |
| `JARDIS_HOST` / `JARDIS_PORT` in `.env` | No — destroy and recreate |
| `USERS_WORKSPACE_PATH` in `.env` | No — destroy and recreate (also restart docker-compose) |
| Bind mount path changes | No — destroy and recreate |
| Repo list changes | Yes (new repos are cloned on next start) |

### Updating the jardis extension

Edit `JARDIS_VERSION` and `JARDIS_VSIX` in `smeuperp/main.tf`, then push the template. Existing workspaces pick up the new version on next start.

### Repos cloned into workspaces

On first start, the following private repos are cloned into `~/smeuperp/libs/` (backed by `$USERS_WORKSPACE_PATH/<username>/libs/` on the host):

```
kokos-dsl-smeuperp
kokos-dsl-smeuperp-custom
kokos-dsl-smeuperp-persup
kokos-dsl-smeuperp-smeupdem
```

To add or remove repos, edit the `REPOS` array in the `startup_script` inside `smeuperp/main.tf` and push the template. Already-cloned repos in existing workspaces are not affected.

---

## Upgrading Coder

Change the image tag in `docker-compose.yml` and restart:

```bash
docker compose up -d
```
