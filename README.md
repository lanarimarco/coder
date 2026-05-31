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
    extensions/          # Place .vsix files here to bundle into the image
```

## Server setup

### 1. Configure secrets

```bash
cp .env.template .env
```

Fill in `.env` with the two GitHub OAuth App credentials (see [GitHub OAuth Apps](#github-oauth-apps) below).

### 2. Start the stack

```bash
docker compose up -d
```

Coder is available at `http://localhost:7080`.

### 3. Create the first admin user

Open `http://localhost:7080` and complete the initial setup wizard.

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

### Push a new version

```bash
coder template push smeuperp --directory smeuperp/
```

### Updating the jardis extension

The jardis extension is downloaded at workspace startup from the private `smeup/jardis` GitHub release. To update the version, edit `JARDIS_VERSION` and `JARDIS_VSIX` in `smeuperp/main.tf`, then push the template. Existing workspaces pick up the new version on next start.

### Bundling other extensions

Drop `.vsix` files into `smeuperp/build/extensions/` and push the template. They are baked into the Docker image and installed on workspace start. The image is only rebuilt when the contents of `build/` change.

### Repos cloned into workspaces

On first start, the following private repos are cloned into `~/smeuperp/libs/`:

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
