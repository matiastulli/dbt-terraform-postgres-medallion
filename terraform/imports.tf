# dev_raw was created by `dbt seed` before Terraform managed schemas; adopt it
# instead of creating a duplicate. The other dbt schemas don't exist yet, so
# Terraform creates them. After apply this block is a no-op and can be deleted.
import {
  to = postgresql_schema.dbt["dev_raw"]
  id = "dbt_learning.dev_raw"
}
