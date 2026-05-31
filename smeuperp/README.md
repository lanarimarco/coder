# smeuperp

Coder workspace template for SMEUP ERP development.

Provides a Docker-based workspace with code-server (VS Code in the browser) and the jardis extension, pre-authenticated against the private `smeup` GitHub org.

## GitHub authentication

### Login to Coder

The Coder login page shows a **Sign in with GitHub** button. Users authenticate with their GitHub account — no PAT required.

> **Prerequisite (admin):** Two GitHub OAuth Apps must be registered and configured in the server's `.env`. See the infrastructure section below.

### Connecting GitHub to your workspace

On first workspace creation, Coder prompts **Connect GitHub** (external auth). This is a one-time step — subsequent workspace creations skip it. The token is used to:

- Download the **jardis** extension from the private `smeup/jardis` release
- Clone the private `smeup` repositories into `~/libs/`
- Authenticate all git operations inside code-server (push, pull, fetch)

The token is written to `~/.git-credentials` via git's credential store on the persistent home volume, so it survives restarts. Remote URLs remain clean (`https://github.com/smeup/<repo>`) — the token is never embedded in `.git/config`.

### Token refresh

OAuth tokens are refreshed automatically by Coder. If a workspace loses GitHub access, go to Coder UI → **Account → External Auth** and reconnect GitHub.

## Infrastructure setup (admin)

### Two OAuth Apps required

Coder needs two separate GitHub OAuth Apps because each has a different callback URL:

| App | Callback URL | Purpose |
|-----|-------------|---------|
| `coder-login` | `http://<host>:7080/api/v2/users/oauth2/github/callback` | Sign in with GitHub on the login page |
| `coder-external` | `http://<host>:7080/external-auth/github/callback` | Workspace git auth via `coder_external_auth` |

Create each at **GitHub → Settings → Developer settings → OAuth Apps → New OAuth App**.

### `.env` configuration

```env
# App #1 — login
GITHUB_CLIENT_ID=<coder-login client id>
GITHUB_CLIENT_SECRET=<coder-login client secret>

# App #2 — workspace external auth
GITHUB_EXTERNAL_AUTH_CLIENT_ID=<coder-external client id>
GITHUB_EXTERNAL_AUTH_CLIENT_SECRET=<coder-external client secret>
```

### Approving the OAuth Apps for the `smeup` org

The `smeup` org has third-party OAuth App access restrictions. Both apps must be approved before they can access private org resources.

**To get an app approved:**

1. A member of the `smeup` org authorizes the app (e.g. by signing in or connecting external auth)
2. Go to **GitHub → Settings → Applications → Authorized OAuth Apps**, click the app, and click **Request access** next to `smeup`
3. The org admin goes to `https://github.com/organizations/smeup/settings/oauth_application_policy` and approves it

> If you are the org admin you can approve your own request immediately after submitting it.

## Workspace folder structure

On first start the following repositories are cloned automatically:

```
~/libs/
├── kokos-dsl-smeuperp
├── kokos-dsl-smeuperp-custom
├── kokos-dsl-smeuperp-persup
└── kokos-dsl-smeuperp-smeupdem
```

Repos are only cloned once — subsequent restarts skip the clone step so local changes are preserved.

## Usage

### Push the template

```bash
coder template push smeuperp --directory /path/to/smeuperp
```

### Create a workspace

From the Coder UI select the **smeuperp** template, or via CLI:

```bash
coder create --template smeuperp <workspace-name>
```

## Structure

```
smeuperp/
├── main.tf               # Terraform template
├── README.md
└── build/
    ├── Dockerfile
    └── extensions/       # Place .vsix files here
```
