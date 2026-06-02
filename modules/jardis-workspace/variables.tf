variable "jardis_host" {
  type = string
}

variable "jardis_port" {
  type = number
}

variable "jardis_env" {
  type = string
}

variable "users_workspace_path" {
  type = string
}

variable "repos" {
  type = list(string)
}

variable "workspace_dir" {
  type    = string
  default = "smeuperp"
}
