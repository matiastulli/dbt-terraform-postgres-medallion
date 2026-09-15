# Read-only role for browsing dbt output (e.g. from DBeaver).
resource "postgresql_role" "analyst" {
  name     = "analyst"
  login    = true
  password = var.analyst_password
}

resource "postgresql_grant" "analyst_connect" {
  database    = postgresql_database.dbt_learning.name
  role        = postgresql_role.analyst.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "analyst_schema_usage" {
  for_each = postgresql_schema.dbt

  database    = postgresql_database.dbt_learning.name
  schema      = each.value.name
  role        = postgresql_role.analyst.name
  object_type = "schema"
  privileges  = ["USAGE"]
}

# SELECT on the tables/views that exist right now...
resource "postgresql_grant" "analyst_select_existing" {
  for_each = postgresql_schema.dbt

  database    = postgresql_database.dbt_learning.name
  schema      = each.value.name
  role        = postgresql_role.analyst.name
  object_type = "table"
  privileges  = ["SELECT"]
}

# ...and on every table/view dbt_user creates later. dbt rebuilds models on
# each run, so without default privileges the grant above would be lost.
resource "postgresql_default_privileges" "analyst_select_future" {
  for_each = postgresql_schema.dbt

  database    = postgresql_database.dbt_learning.name
  schema      = each.value.name
  owner       = postgresql_role.dbt_user.name
  role        = postgresql_role.analyst.name
  object_type = "table"
  privileges  = ["SELECT"]
}
