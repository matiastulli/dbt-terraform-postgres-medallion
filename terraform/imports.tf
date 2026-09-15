# These objects were created by hand with psql before Terraform existed.
# import blocks adopt them into state instead of trying to create duplicates.
# After the first successful apply they are no-ops and can be deleted.

import {
  to = postgresql_role.dbt_user
  id = "dbt_user"
}

import {
  to = postgresql_database.dbt_learning
  id = "dbt_learning"
}
