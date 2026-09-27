# Adopt objects that already exist in Postgres into a fresh (empty) state,
# e.g. after cloning the repo on a machine whose database was built earlier.
# Import IDs: roles and databases by name, schemas as "<database>.<schema>".
# Once applied, this file can be deleted (it's a no-op on later plans).
#
# Grants and default privileges aren't importable with this provider; the plan
# creates them instead, which re-issues GRANTs that already exist (harmless).

import {
  to = postgresql_role.dbt_user
  id = "dbt_user"
}

import {
  to = postgresql_role.analyst
  id = "analyst"
}

import {
  to = postgresql_database.dbt_learning
  id = "dbt_learning"
}

import {
  for_each = local.dbt_schemas
  to       = postgresql_schema.dbt[each.key]
  id       = "dbt_learning.${each.key}"
}
