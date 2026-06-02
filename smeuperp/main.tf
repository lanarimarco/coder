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

provider "docker" {}
provider "coder" {}

module "workspace" {
  source = "./modules/jardis-workspace"

  jardis_host          = "172.31.29.119"
  jardis_port          = 9091
  jardis_env           = "smeuperp-user"
  users_workspace_path = "/home/kokos/users-workspace"
  repos = [
    "kokos-dsl-smeuperp",
    "kokos-dsl-smeuperp-custom",
    "kokos-dsl-smeuperp-persup",
    "kokos-dsl-smeuperp-smeupdem",
  ]
}
