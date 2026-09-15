variable "pg_host" {
  type    = string
  default = "localhost"
}

variable "pg_port" {
  type    = number
  default = 5432
}

variable "pg_admin_user" {
  description = "Postgres superuser Terraform connects as"
  type        = string
  default     = "juanmatiastulli"
}

variable "dbt_user_password" {
  description = "Password for the dbt role. Set via TF_VAR_dbt_user_password (see ../.env)"
  type        = string
  sensitive   = true
}

variable "analyst_password" {
  description = "Password for the read-only analyst role. Set via TF_VAR_analyst_password (see ../.env)"
  type        = string
  sensitive   = true
}
