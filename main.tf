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

data "coder_provisioner" "me" {
}

provider "docker" {
}

data "coder_workspace" "me" {
}

data "coder_external_auth" "github" {
  id = "github"
}

module "filebrowser" {
  source   = "registry.coder.com/modules/filebrowser/coder"
  version  = "1.0.8"
  agent_id = coder_agent.main.id
  folder   = "/var/www/html"
  database_path = "/home/coder/filebrowser.db"
}

module "jetbrains_gateway" {
  source         = "registry.coder.com/modules/jetbrains-gateway/coder"
  version        = "1.0.9"
  agent_id       = coder_agent.main.id
  agent_name     = "main"
  folder         = "/var/www/html"
  jetbrains_ides = ["WS", "IU", "PS"]
  default        = "IU"
}

resource "coder_app" "http" {
  agent_id      = coder_agent.main.id
  slug          = "http"
  display_name  = "Web"
  url           = "http://localhost:80"
  subdomain     = false
}

resource "coder_app" "https" {
  agent_id      = coder_agent.main.id
  slug          = "https"
  display_name  = "Web (SSL)"
  url           = "https://localhost:443"
  subdomain     = false
}

resource "coder_app" "phpmyadmin" {
  agent_id      = coder_agent.main.id
  slug          = "phpmyadmin"
  display_name  = "PHPMyAdmin"
  url           = "https://localhost:4443/phpmyadmin"
  subdomain     = false
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code Web"
  url          = "http://localhost:13337/?folder=/var/www/html"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = "/usr/local/bin/start.sh"
  dir            = "/var/www/html"

  env = {
    GIT_AUTHOR_NAME     = data.coder_workspace.me.owner
    GIT_AUTHOR_EMAIL    = data.coder_workspace.me.owner_email
    GIT_COMMITTER_NAME  = data.coder_workspace.me.owner
    GIT_COMMITTER_EMAIL = data.coder_workspace.me.owner_email
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

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path /var/www/html"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

data "coder_parameter" "repo" {
  name         = "repo"
  display_name = "Repository (auto)"
  order        = 1
  description  = "Select a repository to automatically clone."
  mutable      = true
  option {
    name        = "laravel/laravel"
    icon        = "https://laravel.com/img/logomark.min.svg"
    description = "The Laravel Framework"
    value       = "https://github.com/laravel/laravel"
  }
  option {
    name        = "Custom"
    icon        = "/emojis/1f5c3.png"
    description = "Specify a custom repo URL below"
    value       = "custom"
  }
}

data "coder_parameter" "custom_repo_url" {
  name         = "custom_repo"
  display_name = "Repository URL (custom)"
  order        = 2
  default      = ""
  description  = "Optionally enter a custom repository URL."
  mutable      = true
}

data "coder_parameter" "laravel_seed" {
  name         = "laravel_seed"
  display_name = "Run Laravel Seeder?"
  order        = 3
  description  = "Run db:seed command after setting up project."
  type         = "bool"
  mutable      = true
  default      = false
}

resource "docker_image" "main" {
  name = data.coder_workspace.me.name

  build {
    context = "./build"
    build_args = {
      USER = "coder"
      WORKDIR = "/var/www/html"
    }
  }

  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_network" "private_network" {
  name = "coder-${data.coder_workspace.me.name}-network"
}

resource "docker_container" "dind" {
  image      = "docker:dind"
  privileged = true
  name       = "coder-${data.coder_workspace.me.name}-dind"
  entrypoint = ["dockerd", "-H", "tcp://0.0.0.0:2375"]

  networks_advanced {
    name = docker_network.private_network.name
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count

  image = docker_image.main.name

  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"

  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = data.coder_workspace.me.name

  command = ["sh", "-c", coder_agent.main.init_script]

  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_AGENT_URL=${replace(data.coder_workspace.me.access_url, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")}",
    "INIT_SCRIPT=${replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")}",
    "GIT_URL=${data.coder_parameter.repo.value == "custom" ? data.coder_parameter.custom_repo_url.value : data.coder_parameter.repo.value}",
    "WORKDIR=/var/www/html",
    "SEED=${data.coder_parameter.laravel_seed.value}",
    "DOCKER_HOST=${docker_container.dind.name}:2375"
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  networks_advanced {
    name = docker_network.private_network.name
  }

  volumes {
    container_path = "/var/www/html"
    volume_name    = "coder-${data.coder_workspace.me.name}-project"
    read_only      = false
  }

  volumes {
    container_path = "/var/lib/mysql"
    volume_name    = "coder-${data.coder_workspace.me.name}-mysql"
    read_only      = false
  }

  volumes {
    container_path = "/var/lib/postgresql/data"
    volume_name    = "coder-${data.coder_workspace.me.name}-postgresql"
    read_only      = false
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = "coder-${data.coder_workspace.me.name}-home"
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }

  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }

  lifecycle {
    ignore_changes = all
  }
}
