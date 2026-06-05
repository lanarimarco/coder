# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Self-hosted [Coder](https://coder.com) instance running on Docker Compose, providing jardis-based development workspaces. A single shared Terraform module (`modules/jardis-workspace/`) drives all workspace logic; individual templates are thin callers that pass five values into it.

## Key commands

### Server lifecycle

```bash
docker compose up -d          # Start Coder + PostgreSQL
docker compose down           # Stop
docker compose up -d          # Upgrade (after changing image tag in docker-compose.yml)
```

Coder is available at `http://localhost:7080`.

### Template management

```bash
./new-template.sh <name>      # Scaffold a new template directory (prompts interactively)
./push-template.sh <name>     # Push a template version to the running Coder instance
```

`push-template.sh` uses `cp -rL` to dereference the `modules` symlink before uploading — Coder's provisioner does not follow symlinks.

### Coder CLI

```bash
coder version                 # Check if CLI is installed
coder login http://localhost:7080
coder template push <name> --directory <dir>   # (called by push-template.sh)
```

## Architecture

```
docker-compose.yml              # Coder server (v2.33.6) + PostgreSQL 16
.env                            # Secrets — gitignored, copy from .env.template
modules/
  jardis-workspace/
    main.tf                     # All workspace logic: agent, Docker container, startup script
    variables.tf                # jardis_host, jardis_port, jardis_env, repos, workspace_dir, users_workspace_path
    build/Dockerfile            # Ubuntu base image with sudo/curl/git, workspace user injected via ARG
<template-name>/
  main.tf                       # Thin caller: providers + one module block with template-specific values
  modules -> ../modules         # Symlink — resolved locally, must be dereferenced before push
```

## How the shared module works

`modules/jardis-workspace/main.tf` does everything on workspace start:

1. Installs `code-server` standalone
2. Downloads the jardis VS Code extension from a private GitHub release (only when `JARDIS_VERSION` changes)
3. Installs `barrettotte.ibmi-languages` from Open VSX on every start
4. Clones repos from `github.com/smeup/<repo>` into `$USERS_WORKSPACE_PATH/<username>/libs/` — skips repos already present
5. Injects jardis settings (`host`, `port`, `env`, `user`) into the code-server `settings.json` on every start
6. Creates a `.code-workspace` file with multi-root folders and Jardis launch configs on first start only
7. Starts `code-server` on port 13337

**Persistence model:**
- `~/` is a Docker named volume — private to the workspace, deleted on destroy
- `~/<workspace_dir>/libs` is a bind-mount to `$USERS_WORKSPACE_PATH/<username>/libs/` on the host — survives workspace destroy

## Updating the jardis extension

Edit `JARDIS_VERSION` and `JARDIS_VSIX` in [modules/jardis-workspace/main.tf](modules/jardis-workspace/main.tf) (lines 53–54), then push the template. Existing workspaces pick up the new version on next start.

## What requires workspace destroy vs. stop/start

| Change | Stop/start enough? |
|--------|-------------------|
| `jardis_host` / `jardis_port` / `jardis_env` | Push template, then stop/start |
| Jardis extension version | Stop/start |
| ibmi-languages extension | Stop/start |
| Repo list | Stop/start (new repos cloned on next start) |
| `users_workspace_path` | Destroy and recreate (also restart docker-compose) |
| Bind mount path changes | Destroy and recreate |

## Adding a new template

```bash
./new-template.sh <name>
# Review <name>/main.tf
./push-template.sh <name>
```

The only values that differ between templates are the five in the `module "workspace"` block: `jardis_host`, `jardis_port`, `jardis_env`, `users_workspace_path`, `repos`.

## GitHub OAuth setup

Two separate OAuth Apps are required (different callback URLs):

| App | Callback URL | `.env` variables |
|-----|-------------|-----------------|
| Login | `http://<host>:7080/api/v2/users/oauth2/github/callback` | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` |
| External auth | `http://<host>:7080/external-auth/github/callback` | `GITHUB_EXTERNAL_AUTH_CLIENT_ID`, `GITHUB_EXTERNAL_AUTH_CLIENT_SECRET` |

Both apps need org admin approval for `smeup` org access after first use.
