# dbt-terraform-postgres-medallion

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
| Bronze | `seeds/raw_*.csv`, `models/00_bronze/<source>/_<source>__sources.yml` | `dev_00_bronze` | Raw Jaffle Shop data, no SQL models. `raw_payments.amount` is in **cents**. |
| Silver | `models/01_silver/<source>/` | `dev_01_silver` | One `stg_<entity>` **view** per source table (rename and cast only, every row), then an `int_<entity>` **view** where rows are validated (only valid rows). Raw data enters only via `source()`, in the `stg_` models. |
| Gold | `models/02_gold/` | `dev_02_gold` | A star schema of **tables**, built on `int_` models via `ref()`: `fct_` facts and `dim_` dimensions. |

- Bronze and silver have **one subfolder per source system** (currently only `jaffle_shop/`). Subfolders inherit the layer's schema, so a new source adds a folder, not a schema. YAML files are named per source: `_<source>__sources.yml`, `_<source>__models.yml`. Gold is organised by business entity, not by source.
- Keep the standard model prefixes (`stg_`, `int_`, `dim_`, `fct_`). Model names must be unique project-wide, regardless of folder.
- Materializations and schemas are set per folder in `dbt_project.yml`, not in each model. Folder keys starting with digits are quoted there.
- Each layer also gets a tag (`bronze`, `silver`, `gold`) and a `+docs.node_color` there, so a layer is selectable with `tag:` and coloured in the docs lineage graph. Sources take the tag but not a colour (dbt doesn't support it). A new layer or bronze resource type needs both.
- Seeds are read via `source()`, not `ref()`, to imitate an external loader. So `dbt build` doesn't order seeds before silver; run `dbt seed` first on a fresh database.
- Generic tests live in the model YAMLs (`_jaffle_shop__models.yml`, `_gold_models.yml`) under `data_tests:`. dbt 1.12 expects test arguments nested under `arguments:`. Singular (SQL) tests live in `tests/` and pass when they return zero rows.
- Every key column gets `unique` + `not_null`, because that's what guards each model's grain. In `dbt build`, a failing test SKIPs all downstream models.
- Every model and column has a `description` in the layer YAML. Descriptions reused in several places are doc blocks in `models/docs/<source>.md`, referenced as `'{{ doc("name") }}'`. `+persist_docs` (relation + columns) in `dbt_project.yml` writes them to Postgres as COMMENTs, so they appear in DBeaver. When you add a column, document it in the YAML too.
- **Invalid rows** (silver): `stg_` models never filter. The `int_<entity>` model holds the rules (joins and `where`) and drops invalid rows, so they're kept out of gold instead of failing the build. Dropped rows aren't kept anywhere. Every entity has an `int_` model, even one with no rules yet (`int_customers` is a plain copy), and gold and other `int_` models read only `int_` models.
  - `int_orders` drops orders with a null id or date, a status not in `vars.order_statuses`, or a customer not in `int_customers`.
  - `int_payments` drops payments with a null id, a method not in `vars.payment_methods`, a null or negative amount, or an order not in `int_orders`. Checking against `int_orders` means a payment for a dropped order is dropped too, which keeps `assert_gold_revenue_matches_silver` true.
  - `int_` dependencies go one way, parent entity to child: `int_customers` → `int_orders` → `int_payments`. Each `int_` model owns only its own entity's attributes and validity. A rule that needs the child, such as "drop orders with no payments", goes downstream in gold (`fct_orders`), never back into the parent's `int_` model.
  - Validity tests (`accepted_values`, `relationships`, ranges) go on the `int_` model, since `stg_` still has the bad rows.
- **Star schema** (gold): a `fct_` is an event with measures, one row per event. A `dim_` is the context to filter and group by.
  - Facts: `fct_orders` (one row per order, payments summed per method) and `fct_payments` (one row per payment). Raw payments have no date, so `fct_payments` carries the order's date as `order_date`.
  - Dimensions: `dim_customers` and `dim_dates` (a calendar from `dbt_utils.date_spine`, range set by `vars.dim_dates_start` / `dim_dates_end`; widen it if orders fall outside, the `relationships` tests will say so).
  - Every fact key to a dimension has a `relationships` test. Entities with no attributes beyond their key (`order_id`, `status`, `payment_method`) stay as degenerate dimensions in the facts, not as one-column `dim_` tables.
  - `dim_customers` keeps customer metrics (`number_of_orders`, `lifetime_value`, first and last order) computed from `fct_orders`. Strict Kimball keeps dims free of facts; this shortcut is a deliberate choice.
  - `assert_gold_revenue_matches_silver` checks that `int_payments`, `fct_payments` and `fct_orders` all sum to the same revenue.
  - The seeds contain simulated bad rows on purpose: orders 102 (status `lost`) and 103 (unknown customer 999), and payments 117 (for order 102), 118 (`paypal`) and 119 (negative amount).
- **No snapshots** in the project. `orders_snapshot` (SCD2 history of `raw_orders.status`, `check` strategy) was removed from the code, but its table `dev_00_bronze.orders_snapshot` was left in Postgres on purpose: its history (orders 98 and 99 changing to `shipped`) can't be rebuilt from the CSVs. Never drop it without the user's explicit go-ahead. Restoring `snapshots/orders_snapshot.yml` and the `snapshots:` config in `dbt_project.yml` from git resumes it on the same table.
- `fct_orders` is **incremental** (merge on `order_id`), with a model-level `config()` that overrides the gold folder's `table` default. Incremental runs only reprocess orders within a 3-day lookback of `max(order_date)`. Changes to older orders, such as late payments, are missed until `dbt build --select fct_orders+ --full-refresh`. `assert_gold_revenue_matches_silver` is the test that catches that drift. The seed CSVs contain simulated "new data" beyond the original Jaffle Shop dataset: orders 100–101, payments 114–116 (including a late payment for order 5), and order 98 changed to `shipped`.
- Reusable SQL lives in `macros/` (e.g. `cents_to_dollars()`, used by `stg_payments`). The list of payment methods is set once as `vars.payment_methods` in `dbt_project.yml`. It generates the per-method columns in `fct_orders` with a Jinja loop and feeds the filter and `accepted_values` test in `int_payments`. Changing its order changes `fct_orders`' column order, which fails the build (`on_schema_change='fail'`) until you run `--full-refresh`.
- Packages are listed in `packages.yml` (currently `dbt_utils`). Run `dbt deps` after cloning or changing it: it installs into `dbt_packages/` (gitignored) and writes `package-lock.yml` (commit this). Package tests are namespaced, e.g. `dbt_utils.expression_is_true`.

**Schema naming:** the profile's target schema is `dev`. dbt's default `generate_schema_name` *appends* the custom schema (`dev` + `00_bronze` → `dev_00_bronze`). The `dev_` prefix is also what makes digit-leading names valid unquoted Postgres identifiers.

## Terraform

The user is also learning **Terraform**, step by step in the same style. `terraform/` manages the local Postgres infrastructure dbt runs on, using the `cyrilgdn/postgresql` provider: roles, databases, schemas and grants. Nothing uses the cloud. State is local in `terraform/terraform.tfstate`, which is gitignored because it holds passwords in plain text. Terraform connects as a Postgres superuser with trust auth. Its name comes from `TF_VAR_pg_admin_user`, which has no default: locally `.env` sets it to `$USER`, the Homebrew superuser, and in CI it's `postgres`. Role passwords come from `TF_VAR_dbt_user_password` and `TF_VAR_analyst_password`. `.env.example` is the committed template for `.env`, so update it when you add a variable.

**CI** (`.github/workflows/ci.yml`, GitHub Actions) runs on every push and PR against a fresh `postgres:15` service container. The steps are `terraform fmt -check`, `validate` and `apply -auto-approve` (safe only there, since the database is throwaway), then `dbt deps`, `seed`, `build` and `docs generate`, and finally it uploads the docs as an artifact. dbt versions are pinned in `requirements.txt`; keep them matching `.venv`. `profiles.yml` reads `dbname` from `DBT_PG_DBNAME` (default `dbt_learning`), so the same profile can target a throwaway database. The repo is a public portfolio project (`dbt-terraform-postgres-medallion`), so keep the README polished.

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

## Checks

Before saying a step is done: `dbt build` (after `source .venv/bin/activate && source .env`) and `terraform -chdir=terraform fmt && terraform -chdir=terraform validate`.

## Agents

`.claude/agents/reviewer.md` and `security.md` hold this repo's review checklist and leak checks; they override the global agents of the same name in `~/.claude`. Every repo keeps these two and no others.
