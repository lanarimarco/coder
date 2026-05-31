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

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    set -e

    # Install code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server

    # Install vsix extensions — only when the bundle hash changes
    EXTENSIONS_DIR="/opt/coder-extensions"
    HASH_FILE="$HOME/.coder-extensions-hash"
    CURRENT_HASH=$(find "$EXTENSIONS_DIR" -type f -name "*.vsix" | sort | xargs sha256sum 2>/dev/null | sha256sum | awk '{print $1}')

    if [ ! -f "$HASH_FILE" ] || [ "$(cat $HASH_FILE)" != "$CURRENT_HASH" ]; then
      echo "Installing/updating extensions..."
      for vsix in "$EXTENSIONS_DIR"/*.vsix; do
        [ -f "$vsix" ] && /tmp/code-server/bin/code-server --install-extension "$vsix"
      done
      echo "$CURRENT_HASH" > "$HASH_FILE"
    else
      echo "Extensions up to date, skipping install."
    fi

    # Start code-server
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
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
  name = "coder-smeup-grain-${data.coder_workspace.me.id}"
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
