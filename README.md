# Sales Analytics with dbt & BigQuery

An end-to-end data engineering project that uses **dbt (Data Build Tool)** to transform a **1M+ row** synthetic sales dataset in **Google BigQuery**, with GitHub for version control.

## What It Does

1. **Generates sample data**: a SQL script creates a `raw_sales` table with 1,000,000 random orders in BigQuery.
2. **Stages the data**: `stg_sales` cleans and selects the raw columns (as a view).
3. **Builds a mart**: `sales_final` aggregates orders and revenue by country and product.
4. **Reuses logic with Jinja**: the `dynamic_partition` macro tags each row as `recent` or `historical`.
5. **Tests the output**: dbt tests check key columns for nulls.

## Tech Stack

| Tool | Purpose |
|------|---------|
| dbt Core + `dbt-bigquery` | SQL-based transformations |
| Google BigQuery | Cloud data warehouse |
| Jinja macros | Reusable, dynamic SQL |
| Git / GitHub | Version control |

## Project Structure

```text
dbt_bigquery_project/
├── generate_dataset_query.sql   # Creates the 1M-row raw_sales table in BigQuery
├── dbt_project.yml              # dbt project config (project/profile: sales_analytics)
├── models/
│   ├── staging/
│   │   └── stg_sales.sql        # Staging view over raw_sales
│   └── marts/
│       └── sales_final.sql      # Aggregated revenue by country & product
├── macros/
│   └── dynamic_partition.sql    # Labels rows 'recent' / 'historical'
├── tests/
│   └── sales_tst.yml            # not_null tests on sales_final
├── seeds/  snapshots/  analyses/
└── .gitignore
```

> `profiles.yml` is **not** in this repo. It holds your connection settings and lives in `~/.dbt/` (see step 5).

## Prerequisites

- A Google Cloud project with **BigQuery enabled**
- **Python 3.8+**
- **Google Cloud CLI** (`gcloud`): [install guide](https://cloud.google.com/sdk/docs/install)
- **Git**

## Setup

### 1. Clone the repository

```sh
git clone https://github.com/basim2122/dbt_bigquery_project.git
cd dbt_bigquery_project
```

### 2. Create a virtual environment and install the BigQuery adapter

```sh
python -m venv dbt-env

# Windows (PowerShell)
.\dbt-env\Scripts\Activate.ps1
# macOS / Linux
source dbt-env/bin/activate

pip install dbt-bigquery        # installs dbt Core + the BigQuery adapter
dbt --version                   # confirm the install
```

### 3. Authenticate with Google Cloud

```sh
gcloud auth application-default login
```

This opens a browser window. Your credentials are saved locally, and dbt uses them through the `oauth` method.

### 4. Initialize the dbt project (first-time setup only)

The project was originally created with:

```sh
dbt init sales_analytics
```

`dbt init` asks for the adapter (`bigquery`), the auth method (`oauth`), your GCP project ID, the dataset and the thread count. It then writes `~/.dbt/profiles.yml` for you.

> If you cloned this repo, you don't need to scaffold a new project. Run `dbt init` only to create the profile, or write `profiles.yml` by hand as shown in the next step.

### 5. Configure `profiles.yml`

Location: `~/.dbt/profiles.yml` (Windows: `C:\Users\<you>\.dbt\profiles.yml`)

```yaml
sales_analytics:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: <your-gcp-project-id>
      dataset: sales_dataset
      threads: 4
      location: US
      job_execution_timeout_seconds: 300
```

The top-level key must match `profile: 'sales_analytics'` in `dbt_project.yml`.

### 6. Generate the sample dataset

Open [generate_dataset_query.sql](generate_dataset_query.sql), replace `your_project.your_dataset` with your project and dataset, and run it in the BigQuery console:

```sql
CREATE OR REPLACE TABLE <your-gcp-project-id>.sales_dataset.raw_sales AS
WITH raw_data AS (
  SELECT
    GENERATE_UUID() AS order_id,
    ARRAY<STRING>['Laptop', 'Phone', 'Tablet', 'Headphones', 'Monitor'][OFFSET(CAST(FLOOR(RAND() * 5) AS INT64))] AS product_name,
    CAST(FLOOR(RAND() * 7000 + 100) AS INT64) AS amount,
    ARRAY<STRING>['USA', 'UK', 'Canada', 'Germany', 'France'][OFFSET(CAST(FLOOR(RAND() * 5) AS INT64))] AS country,
    DATE_ADD(DATE '2024-01-01', INTERVAL CAST(FLOOR(RAND() * 365) AS INT64) DAY) AS order_date,
    CAST(FLOOR(RAND() * 100) AS INT64) AS discount
  FROM UNNEST(GENERATE_ARRAY(1, 1000000))
)
SELECT * FROM raw_data;
```

Then update the source table in [models/staging/stg_sales.sql](models/staging/stg_sales.sql) to point at your project:

```sql
FROM `<your-gcp-project-id>.sales_dataset.raw_sales`
```

### 7. Run the pipeline

```sh
dbt debug     # check the BigQuery connection and profile
dbt run       # build stg_sales (view) and sales_final
dbt test      # run the data tests
dbt build     # or: run + test in one step
```

Optional: generate and view the documentation site:

```sh
dbt docs generate
dbt docs serve
```

## Models

| Model | Layer | Materialization | Description |
|-------|-------|-----------------|-------------|
| `stg_sales` | Staging | view | Selects order columns from `raw_sales` and adds `partition_group` |
| `sales_final` | Mart | table (dbt default) | `total_orders` and `total_revenue` by `country`, `product_name`, `partition_group` |

### Macro: `dynamic_partition(column_name, interval)`

```sql
{{ dynamic_partition('order_date', 'MONTH') }}
```

Returns `'recent'` when the date falls within the last 3 intervals (for example, 3 months) and `'historical'` otherwise, as the column `partition_group`.

## Tests

Defined in [tests/sales_tst.yml](tests/sales_tst.yml):

- `sales_final.country`: not null
- `sales_final.total_orders`: not null

## Command Cheat Sheet

| Command | Purpose |
|---------|---------|
| `pip install dbt-bigquery` | Install dbt with the BigQuery adapter |
| `dbt init sales_analytics` | Scaffold a new dbt project and profile |
| `gcloud auth application-default login` | Authenticate to BigQuery |
| `dbt debug` | Test the connection |
| `dbt run` | Build the models |
| `dbt test` | Run the tests |
| `dbt run --select sales_final` | Build a single model |
| `dbt clean` | Remove `target/` and `dbt_packages/` |
