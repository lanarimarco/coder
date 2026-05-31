# smeuperp

Coder workspace template for SMEUP ERP development.

Provides a Docker-based workspace with code-server (VS Code in the browser) and pre-installed custom extensions.

## Extensions

Drop `.vsix` files into `build/extensions/` before pushing the template. They are baked into the Docker image and installed automatically on first workspace start.

Extensions are only reinstalled when the bundle changes — subsequent restarts skip the install step for faster startup.

### Adding or updating an extension

1. Replace or add the `.vsix` file in `build/extensions/`
2. Push the updated template:
   ```bash
   coder template push smeuperp --directory /path/to/smeuperp
   ```
3. Users click **Update** on their workspace — the new extension is installed on next start.

## GitHub authentication

### On workspace creation

When creating a workspace you will be prompted for a **GitHub Personal Access Token (PAT)**. The token must have read access to the private repos in the `smeup` organisation.

To generate one: GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → select the `smeup` org repos with **Contents: Read**.

### How the token is used

On first start the token is written to `~/.git-credentials` via git's built-in credential store:

```
https://oauth2:<token>@github.com
```

This file lives on the **persistent home volume**, so it survives workspace restarts. All subsequent git operations inside code-server (push, pull, fetch) use it automatically — the user is never prompted for credentials again.

The remote URLs in each cloned repo are clean (`https://github.com/smeup/<repo>`) — the token is not embedded in `.git/config`.

### When the token expires

Delete and recreate the workspace with a new token. The home volume (your files and git history) is preserved — only the credentials file is refreshed.

> **Note:** The GitHub PAT is unrelated to Coder's user authentication. Keycloak (planned) handles login to the Coder platform itself; the PAT is always required separately for git operations against GitHub private repos.

## Workspace folder structure

On first start the following repositories are cloned automatically into the user's home directory:

```
~/libs/
├── kokos-dsl-smeuperp
├── kokos-dsl-smeuperp-custom
├── kokos-dsl-smeuperp-persup
└── kokos-dsl-smeuperp-smeupdem
```

Repos are only cloned once — subsequent workspace restarts skip the clone step so local changes are preserved.

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
