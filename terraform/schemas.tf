# Schemas dbt builds into. dbt appends custom schemas to the target schema
# ("dev"), so these must match the +schema configs in ../dbt_project.yml.
locals {
  dbt_schemas = toset(["dev_00_bronze", "dev_01_silver", "dev_02_gold"])
}

# One resource block, one instance per schema: postgresql_schema.dbt["dev_raw"], ...
resource "postgresql_schema" "dbt" {
  for_each = local.dbt_schemas

  name     = each.key
  database = postgresql_database.dbt_learning.name
  owner    = postgresql_role.dbt_user.name
}
