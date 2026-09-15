# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A personal **learning project for dbt**. It runs fully local with dbt-core and the free `dbt-postgres` adapter, with no dbt Cloud. It uses the dbt Labs **Jaffle Shop** dataset. The user is a freelancer learning dbt **step by step**, so explain each new dbt concept as you introduce it. Build in stages rather than scaffolding everything at once:
seeds → sources + staging → marts → tests → docs → snapshots → incremental models → macros/packages.

## Environment

- PostgreSQL 15 (Homebrew service `postgresql@15`) on `localhost:5432`. The user browses results in **DBeaver**.
- Database `dbt_learning`, owned by role `dbt_user`. Local-only password in `.env`, which is gitignored.
- dbt-core 1.12 + dbt-postgres, installed in `.venv/` with the system Python 3.11.
- `profiles.yml` lives **in the repo root**, not `~/.dbt/`. It reads the password from `DBT_PG_PASSWORD`.

## Commands

Always load the env first so dbt finds the in-repo profile and password:

```sh
source .venv/bin/activate && source .env
dbt debug                       # check connection/config
dbt seed                        # load seeds/*.csv into Postgres
dbt run                         # build models
dbt test                        # run data tests
dbt build                       # seed + run + test + snapshot in DAG order
dbt build --select stg_orders   # a single model (plus its tests)
dbt build --select +fct_orders  # a model and everything upstream
dbt test --select stg_orders    # tests for a single model
dbt docs generate && dbt docs serve   # lineage/docs site on localhost:8080
psql -h localhost -U dbt_user -d dbt_learning   # inspect results
```

## Layout conventions

- `seeds/raw_*.csv` hold the Jaffle Shop raw data. `raw_payments.amount` is in **cents**.
- `models/staging/`: one `stg_<entity>` view per source table (renaming, casting). Materialized as views.
- `models/marts/`: business-facing `dim_`/`fct_` tables. Materialized as tables.
- Folder-level materializations and schemas are set in `dbt_project.yml`, not in each model.

## Terraform

The user is also learning **Terraform**, step by step in the same style. `terraform/` manages the local Postgres infrastructure dbt runs on, using the `cyrilgdn/postgresql` provider: roles, databases and, later, schemas and grants. Nothing uses the cloud. State is local in `terraform/terraform.tfstate`, which is gitignored because it holds the password in plain text. Terraform connects as the Homebrew superuser `juanmatiastulli` with trust auth. The `dbt_user` password comes from `TF_VAR_dbt_user_password`, set in `.env`.

Terraform manages the `dbt_user` role, the `dbt_learning` database and the dbt schemas (`local.dbt_schemas` in `terraform/schemas.tf`). It also manages a read-only `analyst` role for DBeaver, with password `TF_VAR_analyst_password`. Its SELECT access comes from both a grant on existing tables and default privileges for tables `dbt_user` creates later, because dbt rebuilds models on every run. **If you add a new dbt `+schema`, also add `dev_<name>` to `local.dbt_schemas`.** Otherwise the analyst can't read it. `dbt_user`, `dbt_learning` and `dev_raw` were created before Terraform and adopted with `import` blocks. Change these objects through Terraform, not with manual `psql` DDL, or state will drift.

The user wants to read plans before applying. Save them with `plan -out=tfplan` and don't `apply` without their go-ahead.

```sh
source .env
terraform -chdir=terraform plan     # preview changes
terraform -chdir=terraform apply
terraform -chdir=terraform fmt && terraform -chdir=terraform validate
```

**Schema naming:** the profile's target schema is `dev`. dbt's default `generate_schema_name` *appends* custom schemas, so seeds land in `dev_raw`, staging in `dev_staging` and marts in `dev_marts`. Look there in DBeaver/psql, not in `raw`/`staging`.
