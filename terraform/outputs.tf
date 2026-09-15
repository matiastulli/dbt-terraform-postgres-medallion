output "analyst_connection" {
  description = "Connection settings for DBeaver (password is TF_VAR_analyst_password)"
  value = {
    host     = var.pg_host
    port     = var.pg_port
    database = postgresql_database.dbt_learning.name
    username = postgresql_role.analyst.name
  }
}

output "dbt_schemas" {
  value = sort([for s in postgresql_schema.dbt : s.name])
}
