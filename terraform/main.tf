resource "postgresql_role" "dbt_user" {
  name     = "dbt_user"
  login    = true
  password = var.dbt_user_password
}

resource "postgresql_database" "dbt_learning" {
  name  = "dbt_learning"
  owner = postgresql_role.dbt_user.name
}
