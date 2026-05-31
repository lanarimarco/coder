terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

locals {
  username = data.coder_workspace_owner.me.name
}

data "coder_provisioner" "me" {}

provider "docker" {}

provider "coder" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

data "coder_external_auth" "github" {
  id = "github"
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    set -e

    # Install code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server

    GH_TOKEN="$GITHUB_TOKEN"

    # Configure git credential store so all git operations in code-server work without re-authentication
    git config --global credential.helper store
    echo "https://$GH_TOKEN@github.com" > "$HOME/.git-credentials"
    chmod 600 "$HOME/.git-credentials"

    # Download and install jardis extension — only when version changes
    # Uses the GitHub API (not browser URL) which correctly handles private release assets
    JARDIS_VERSION="v2.0.0"
    JARDIS_VSIX="jardis-client-v2.0.0.vsix"
    JARDIS_VERSION_FILE="$HOME/.coder-jardis-vsix-version"

    if [ -n "$GH_TOKEN" ] && { [ ! -f "$JARDIS_VERSION_FILE" ] || [ "$(cat $JARDIS_VERSION_FILE)" != "$JARDIS_VERSION" ]; }; then
      echo "Downloading jardis extension $JARDIS_VERSION..."
      ASSET_URL=$(curl -fsSL \
        -H "Authorization: token $GH_TOKEN" \
        "https://api.github.com/repos/smeup/jardis/releases/tags/$JARDIS_VERSION" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(next(a['url'] for a in d['assets'] if a['name']=='$JARDIS_VSIX'))")
      curl -fsSL \
        -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/octet-stream" \
        "$ASSET_URL" -o /tmp/jardis-client.vsix
      /tmp/code-server/bin/code-server --install-extension /tmp/jardis-client.vsix
      rm /tmp/jardis-client.vsix
      echo "$JARDIS_VERSION" > "$JARDIS_VERSION_FILE"
    else
      echo "jardis extension up to date, skipping."
    fi

    # Clone smeup libs — only on first start, preserves user changes on restarts
    # Token is embedded in the URL to bypass Coder's GIT_ASKPASS interceptor,
    # then immediately stripped from the remote so it never persists in .git/config
    LIBS_DIR="$HOME/libs"
    REPOS=(
      "kokos-dsl-smeuperp"
      "kokos-dsl-smeuperp-custom"
      "kokos-dsl-smeuperp-persup"
      "kokos-dsl-smeuperp-smeupdem"
    )
    mkdir -p "$LIBS_DIR"
    for NAME in "$${REPOS[@]}"; do
      DEST="$LIBS_DIR/$NAME"
      if [ ! -d "$DEST/.git" ]; then
        echo "Cloning $NAME..."
        git clone "https://$GH_TOKEN@github.com/smeup/$NAME" "$DEST"
        git -C "$DEST" remote set-url origin "https://github.com/smeup/$NAME"
      else
        echo "$NAME already cloned, skipping."
      fi
    done

    # Start code-server
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
    GITHUB_TOKEN        = data.coder_external_auth.github.access_token
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_image" "main" {
  name = "coder-smeuperp-${data.coder_workspace.me.id}"
  build {
    context = "./build"
    build_args = {
      USER = local.username
    }
  }
  # Rebuild image whenever anything in build/ changes (including new/updated vsix files)
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/**") : filesha1(f)]))
  }
}

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.main.name
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/${local.username}"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
}
