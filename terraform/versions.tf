terraform {
  required_version = ">= 1.5"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.0"
    }
  }
}

# Terraform connects as the Homebrew superuser (local trust auth, no password)
# so it can create roles and databases.
provider "postgresql" {
  host     = var.pg_host
  port     = var.pg_port
  username = var.pg_admin_user
  database = "postgres"
  sslmode  = "disable"
}
