# Snowflake ETL Framework

Dynamic, metadata-driven ETL pattern for loading dimension and fact tables using hash-based change detection.

## Quick Start

```sql
-- 1. Deploy procedures from Git
@your_repo/branches/main/src/etl/procs/table_updater.sql;
@your_repo/branches/main/src/etl/procs/dag_orchestrator.sql;

-- 2. Create DAG orchestrator
CALL etl.create_dag_orchestrator('learning_db', 'etl', 'COMPUTE_WH', NULL);

-- 3. Execute
EXECUTE TASK etl.etl_dag_orchestrator;
```

## Components

### table_updater.sql
Generic upsert procedure that works with any table through metadata introspection.

**Usage:**
```sql
CALL etl.table_updater('dim_employee');
```

**Requirements:**
- Target table: `{database}.dw.{table_name}` with PRIMARY KEY defined
- Source view: `{database}.etl.vw_{table_name}` with `etl_row_hash_value` column

### dag_orchestrator.sql
Creates Snowflake Task DAG that orchestrates loads in dependency order (dims → facts).

**Usage:**
```sql
-- Manual execution
CALL etl.create_dag_orchestrator('learning_db', 'etl', 'COMPUTE_WH', NULL);

-- Scheduled (every 60 minutes)
CALL etl.create_dag_orchestrator('learning_db', 'etl', 'COMPUTE_WH', 60);
```

## Table Structure

All tables must follow this pattern:

```sql
CREATE TABLE dw.{table_name} (
    {table_name}_key BIGINT AUTOINCREMENT,      -- Surrogate key
    {natural_key_columns},                       -- Business keys
    {business_columns},                          -- Data columns
    etl_row_hash_value STRING,                  -- SHA1 hash for change detection
    create_username STRING,                      -- Audit columns
    create_datetime TIMESTAMP_NTZ,
    last_update_username STRING,
    last_update_datetime TIMESTAMP_NTZ
);

ALTER TABLE dw.{table_name} 
ADD CONSTRAINT pk_{table_name} PRIMARY KEY ({natural_key_columns});
```

## View Structure

All views must include hash of business columns:

```sql
CREATE VIEW etl.vw_{table_name} AS
SELECT
     {natural_key_columns}
    ,{business_columns}
    ,SHA1(CONCAT_WS('|',
        COALESCE(CAST({col1} AS STRING), '|'),
        COALESCE(CAST({col2} AS STRING), '|')
    )) AS etl_row_hash_value
FROM {source_table};
```

## How It Works

1. **identify_upserts**: LEFT JOIN view to table, compare hashes, create staging table
2. **process_table_updates**: MERGE to update changed rows
3. **process_table_inserts**: MERGE to insert new rows

Audit columns are automatically maintained.

## Adding New Tables

1. Create table with structure above
2. Add PRIMARY KEY constraint
3. Create view with `etl_row_hash_value`
4. Add to DAG orchestrator if needed

To add tasks to DAG, edit `dag_orchestrator.sql`:

```python
task_new = DAGTask(
    name="load_new_table",
    definition=f"CALL {database_name}.{schema_name}.table_updater('new_table');"
)
task_dim >> task_new >> task_fact
```

## Monitoring

```sql
-- View DAG execution history
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'etl_dag_orchestrator'
)) ORDER BY SCHEDULED_TIME DESC;

-- Suspend/Resume scheduling
ALTER TASK etl.etl_dag_orchestrator SUSPEND;
ALTER TASK etl.etl_dag_orchestrator RESUME;
```

## Key Features

- Metadata-driven (no hardcoded columns)
- Hash-based change detection (efficient upserts)
- Automatic audit trail
- Works with composite primary keys
- Environment-agnostic (dev/staging/prod)
