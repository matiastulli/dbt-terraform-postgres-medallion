-----
Status: #IN_PROGRESS, building on feat/observability
-----

# Observability: dropped rows and run log

**Date:** 2026-11-10
**Scope:** `terraform/schemas.tf`, `dbt_project.yml`, `tests/generic/`, `macros/`, silver model YAML, `AGENTS.md`, `README.md`

## Context

The `int_` models drop invalid rows and keep them nowhere. If `raw_orders` arrived with 30% bad statuses, `dbt build` would still pass and gold would silently lose 30% of its orders. Existing tests cover keys, validity on `int_` and revenue reconciliation, but nothing reports **how many** rows were dropped, **which** ones, or how that changes between runs.

This plan adds two things, both writing to a new `audit` schema (`dev_audit`). It isn't a medallion layer, so it gets no number.

1. **Dropped-row rule.** A custom generic test, `dropped_rows`, on each `int_` model returns the `stg_` rows that didn't make it through. `warn_if: ">0"` with an `error_if` threshold reports a few drops without blocking and stops the build on many. The severity stays `error` (the default): with `severity: warn`, dbt ignores `error_if`. `store_failures: true` keeps the dropped rows in a table in `dev_audit`, so they can be inspected in DBeaver.
2. **Run log.** An `on-run-end` hook calls a macro that appends one row per executed node to `dev_audit.run_log`: `invocation_id`, run start, node id, resource type, status, rows affected, failures and execution time. Append-only, so history is derived from it, never overwritten. A test's `failures` is its dropped-row count, so the log answers "how many rows did `int_orders` drop in each run?".

New dbt concepts: generic tests with arguments, `warn_if`/`error_if`, `store_failures`, `on-run-end` hooks, the `results` and `invocation_id` context variables.

Known limits, accepted:
- `dropped_rows` shows **which** rows were dropped, not **why**. The rules live only in the `int_` model, and repeating them in the test would create a second copy that can drift. The stored row usually makes the reason obvious (status `lost`, customer `999`).
- `error_if` takes an absolute count, not a percentage. That's fine at this data size. The count is `vars.max_dropped_rows` (10), so it can be changed per run with `--vars`.
- The seeds contain bad rows on purpose (orders 102 and 103, payments 117 to 119), so the warning fires on every build. That's expected.

Found while building, out of scope: local `dbt build`s with 4 threads sometimes hit a Postgres `deadlock detected` while swapping the `stg_orders` view. It reproduces with `dbt run --select 01_silver` alone (1 in 15 runs), so these changes don't cause it. Likely cause: the view swaps' `drop ... cascade` on views that share dependents (`int_orders` reads `stg_orders` and `int_customers`). CI starts from an empty database, so it never swaps views. To be handled in its own fix.

Out of scope, next steps: volume rules against `run_log` history (for example, `fct_orders` must not shrink more than 20% between runs), then Elementary. Source freshness doesn't fit: the seeds have no load timestamp.

## Tasks

1. **Schema (delivery path first).** Add `dev_audit` to `local.dbt_schemas` in `terraform/schemas.tf`. The analyst grants loop over `postgresql_schema.dbt`, so they follow automatically. Run `plan -out=tfplan` and stop for Juan's review before `apply`.
2. **Route tests to `audit`.** In `dbt_project.yml`, add `data_tests: jaffle_shop: +schema: audit`. Only the tests that set `store_failures` write anything there.
3. **`dropped_rows` test.** Add `tests/generic/dropped_rows.sql`: `dropped_rows(model, column_name, upstream)` returns the rows of `upstream` whose key isn't in `model`. (`from` would clash with Jinja's `from` keyword.) Attach it to `int_orders.order_id` (from `stg_orders`) and `int_payments.payment_id` (from `stg_payments`), named `int_orders_dropped_rows` / `int_payments_dropped_rows` (also their table names), with `warn_if: ">0"`, `error_if: ">{{ var('max_dropped_rows') }}"` and `store_failures: true`. `int_customers` has no rules yet, so it gets none.
4. **Run log.** Add `macros/log_run_results.sql`. It runs `create table if not exists dev_audit.run_log (...)` and inserts one row per entry in `results`. Wire it up in `dbt_project.yml` with `on-run-end`. Build the schema name from `target.schema`, so CI's throwaway database works too.
5. **Docs.** Describe each test in the YAML, document the run log in its macro, then AGENTS.md (layout conventions, the new schema) and the README (DBeaver queries for the dropped rows and the run log).
6. **CI.** Push and confirm the workflow passes. Terraform creates `dev_audit` there before `dbt build`.

## Acceptance criteria

- [x] `terraform plan` shows only the new `dev_audit` schema and its analyst grants, reviewed by Juan before `apply`.
- [x] `dbt build` passes, with two `dropped_rows` warnings: 2 orders and 3 payments.
- [x] `dev_audit` holds the stored failures and lists exactly orders 102 and 103 and payments 117, 118 and 119.
- [x] `dbt build --vars '{max_dropped_rows: 1}'` turns both warnings into errors and skips the models downstream of `int_orders` and `int_payments`. A normal `dbt build` afterwards restores everything.
- [x] Two `dbt build`s in a row leave two `invocation_id`s in `run_log`. Rows are appended, never replaced.
- [x] The `analyst` role can select from `dev_audit` in DBeaver.
- [ ] CI passes.

## Reference

- [dbt: `store_failures`](https://docs.getdbt.com/reference/resource-configs/store_failures)
- [dbt: `severity`, `warn_if`, `error_if`](https://docs.getdbt.com/reference/resource-configs/severity)
- [dbt: `on-run-start` / `on-run-end`](https://docs.getdbt.com/reference/project-configs/on-run-start-on-run-end)
- [dbt: `results` context variable](https://docs.getdbt.com/reference/dbt-jinja-functions/on-run-end-context)
