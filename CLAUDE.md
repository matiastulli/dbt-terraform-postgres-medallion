# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A personal **learning project for dbt**. It runs fully local with dbt-core and the free `dbt-postgres` adapter, with no dbt Cloud. It uses the dbt Labs **Jaffle Shop** dataset. The user is a freelancer learning dbt **step by step**, so explain each new dbt concept as you introduce it. Build in stages rather than scaffolding everything at once:
seeds → sources + silver → gold → tests → docs → snapshots → incremental models → macros/packages.

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
dbt build --select 01_silver    # a whole layer (folder)
dbt test --select stg_orders    # tests for a single model
dbt docs generate && dbt docs serve   # lineage/docs site on localhost:8080
psql -h localhost -U dbt_user -d dbt_learning   # inspect results
```

`README.md` is the user's full command reference for dbt, Terraform and psql. Keep it up to date when commands or setup change.

**Never run `--empty` against the `dev` target.** It rebuilds the selected models with zero rows, replacing the real views and tables. Use `dbt show` / `dbt compile` to check SQL instead.

## Layout conventions

The project uses **numbered medallion layers**, which is the user's preferred convention. Folder name = custom schema name:

| Layer | Where | Schema | Contents |
|---|---|---|---|
| Bronze | `seeds/raw_*.csv`, `models/00_bronze/_sources.yml` | `dev_00_bronze` | Raw Jaffle Shop data, no SQL models. `raw_payments.amount` is in **cents**. |
| Silver | `models/01_silver/` | `dev_01_silver` | One `stg_<entity>` **view** per source (rename, cast). Reads only via `source()`. |
| Gold | `models/02_gold/` | `dev_02_gold` | Business-facing `dim_`/`fct_` **tables**, built on silver via `ref()`. |

- Keep the standard model prefixes (`stg_`, `dim_`, `fct_`). Model names must be unique project-wide, regardless of folder.
- Materializations and schemas are set per folder in `dbt_project.yml`, not in each model. Folder keys starting with digits are quoted there.
- Seeds are read via `source()`, not `ref()`, to imitate an external loader. So `dbt build` doesn't order seeds before silver; run `dbt seed` first on a fresh database.
- Generic tests live in one YAML per layer (`_silver_models.yml`, `_gold_models.yml`) under `data_tests:`. dbt 1.12 expects test arguments nested under `arguments:`. Singular (SQL) tests live in `tests/` and pass when they return zero rows.
- Every key column gets `unique` + `not_null`, because that's what guards each model's grain. In `dbt build`, a failing test SKIPs all downstream models.
- Every model and column has a `description` in the layer YAML. Descriptions reused in several places are doc blocks in `models/_docs.md`, referenced as `'{{ doc("name") }}'`. `+persist_docs` (relation + columns) in `dbt_project.yml` writes them to Postgres as COMMENTs, so they appear in DBeaver. When you add a column, document it in the YAML too.
- Snapshots are defined in YAML in `snapshots/` and built into `dev_00_bronze`, since they hold history of raw data. `orders_snapshot` snapshots the **source** `raw_orders` with the `check` strategy on `status`, because the raw data has no `updated_at`. Never drop the snapshot table: its history can't be rebuilt from the CSVs. Snapshot changes are simulated by editing a seed CSV, then running `dbt seed` followed by `dbt snapshot`. Seeds aren't upstream of the snapshot (it reads a `source()`), so `dbt build` doesn't guarantee that order. Order 99 was changed from `placed` to `shipped` this way.
- `fct_orders` is **incremental** (merge on `order_id`), with a model-level `config()` that overrides the gold folder's `table` default. Incremental runs only reprocess orders within a 3-day lookback of `max(order_date)`. Changes to older orders, such as late payments, are missed until `dbt build --select fct_orders+ --full-refresh`. `assert_gold_revenue_matches_silver` is the test that catches that drift. The seed CSVs contain simulated "new data" beyond the original Jaffle Shop dataset: orders 100–101, payments 114–116 (including a late payment for order 5), and order 98 changed to `shipped`.
- Reusable SQL lives in `macros/` (e.g. `cents_to_dollars()`, used by `stg_payments`). The list of payment methods is set once as `vars.payment_methods` in `dbt_project.yml`. It generates the per-method columns in `fct_orders` with a Jinja loop and feeds the `accepted_values` test. Changing its order changes `fct_orders`' column order, which fails the build (`on_schema_change='fail'`) until you run `--full-refresh`.
- Packages are listed in `packages.yml` (currently `dbt_utils`). Run `dbt deps` after cloning or changing it: it installs into `dbt_packages/` (gitignored) and writes `package-lock.yml` (commit this). Package tests are namespaced, e.g. `dbt_utils.expression_is_true`.

**Schema naming:** the profile's target schema is `dev`. dbt's default `generate_schema_name` *appends* the custom schema (`dev` + `00_bronze` → `dev_00_bronze`). The `dev_` prefix is also what makes digit-leading names valid unquoted Postgres identifiers.

## Terraform

The user is also learning **Terraform**, step by step in the same style. `terraform/` manages the local Postgres infrastructure dbt runs on, using the `cyrilgdn/postgresql` provider: roles, databases, schemas and grants. Nothing uses the cloud. State is local in `terraform/terraform.tfstate`, which is gitignored because it holds passwords in plain text. Terraform connects as the Homebrew superuser `juanmatiastulli` with trust auth. Role passwords come from `TF_VAR_dbt_user_password` and `TF_VAR_analyst_password`, set in `.env`.

Terraform manages the `dbt_user` role, the `dbt_learning` database and the dbt layer schemas (`local.dbt_schemas` in `terraform/schemas.tf`). It also manages a read-only `analyst` role for DBeaver. The analyst's SELECT access comes from both a grant on existing tables and default privileges for tables `dbt_user` creates later, because dbt rebuilds models on every run. **If you add a new dbt `+schema`, also add `dev_<name>` to `local.dbt_schemas`.** Otherwise the analyst can't read it.

`dbt_user`, `dbt_learning` and the bronze schema (originally `dev_raw`) were created before Terraform and adopted with `import` blocks. The schemas were later renamed to the medallion names using `moved` blocks (`terraform/moved.tf`). Postgres renames schemas in place, but grants on them are replaced. Change these objects through Terraform, not with manual `psql` DDL, or state will drift.

The user wants to read plans before applying. Save them with `plan -out=tfplan` and don't `apply` without their go-ahead.

```sh
source .env
terraform -chdir=terraform plan -out=tfplan   # preview changes
terraform -chdir=terraform show tfplan
terraform -chdir=terraform apply tfplan
terraform -chdir=terraform fmt && terraform -chdir=terraform validate
```
