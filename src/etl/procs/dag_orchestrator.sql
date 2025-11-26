CREATE OR REPLACE PROCEDURE etl.create_dag_orchestrator(
    target_database VARCHAR,
    target_schema VARCHAR,
    warehouse_name VARCHAR DEFAULT 'COMPUTE_WH',
    schedule_minutes INT DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
from snowflake.core.task.dagv1 import DAG, DAGTask, DAGOperation
from snowflake.core import CreateMode, Root
import textwrap

def main(session, target_database: str, target_schema: str, warehouse_name: str, schedule_minutes: int) -> str:
    """
    Creates a DAG that orchestrates ETL loads in dependency order:
    1. dim_employee (runs first)
    2. fact_employee_pay (runs after dim_employee succeeds)
    
    Args:
        session: Snowflake session object
        target_database: Database where DAG and tables are located (e.g., 'learning_db', 'dev_db', 'prod_db')
        target_schema: Schema where DAG will be created (typically 'etl')
        warehouse_name: Warehouse to use for task execution
        schedule_minutes: If provided, schedules DAG to run every N minutes. If None, manual execution only.
    
    Returns:
        Success message with DAG details
        
    Usage Examples:
        -- Create DAG for manual execution
        CALL etl.create_dag_orchestrator('learning_db', 'etl', 'COMPUTE_WH', NULL);
        
        -- Create DAG with automatic scheduling (every 60 minutes)
        CALL etl.create_dag_orchestrator('learning_db', 'etl', 'COMPUTE_WH', 60);
        
        -- Execute the DAG manually
        EXECUTE TASK learning_db.etl.etl_dag_orchestrator;
        
        -- View task history
        SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'etl_dag_orchestrator'))
        ORDER BY SCHEDULED_TIME DESC;
        
        -- Suspend/Resume
        ALTER TASK learning_db.etl.etl_dag_orchestrator SUSPEND;
        ALTER TASK learning_db.etl.etl_dag_orchestrator RESUME;
    """
    
    try:
        # Use explicitly provided database and schema
        database_name = target_database
        schema_name = target_schema
        
        # Create Root object for DAG operations
        root = Root(session)
        
        # Define the DAG
        dag_config = {
            'name': 'etl_dag_orchestrator',
            'warehouse': warehouse_name
        }
        
        # Add schedule if provided
        if schedule_minutes:
            dag_config['schedule'] = f'{schedule_minutes} MINUTE'
        
        with DAG(**dag_config) as dag:
            # Task 1: Load dim_employee
            task_dim_employee = DAGTask(
                name="load_dim_employee",
                definition=f"CALL {database_name}.{schema_name}.table_updater('dim_employee');",
                comment="Load dimension table: dim_employee"
            )
            
            # Task 2: Load fact_employee_pay (depends on dim_employee)
            task_fact_employee_pay = DAGTask(
                name="load_fact_employee_pay",
                definition=f"CALL {database_name}.{schema_name}.table_updater('fact_employee_pay');",
                comment="Load fact table: fact_employee_pay"
            )
            
            # Define dependency: fact_employee_pay waits for dim_employee to succeed
            task_dim_employee >> task_fact_employee_pay
        
        # Deploy the DAG
        dag_op = DAGOperation(root.databases[database_name].schemas[schema_name])
        dag_op.deploy(dag, mode=CreateMode.or_replace)
        
        # Build success message
        schedule_msg = f" (scheduled every {schedule_minutes} minutes)" if schedule_minutes else " (manual execution only)"
        success_msg = textwrap.dedent(f"""
            DAG 'etl_dag_orchestrator' created successfully in {database_name}.{schema_name}{schedule_msg}
            
            Tasks:
              1. load_dim_employee (runs first)
              2. load_fact_employee_pay (runs after dim_employee succeeds)
            
            To execute manually:
              EXECUTE TASK {database_name}.{schema_name}.etl_dag_orchestrator;
            
            To view task history:
              SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'etl_dag_orchestrator')) 
              ORDER BY SCHEDULED_TIME DESC;
            
            To suspend (stop scheduling):
              ALTER TASK {database_name}.{schema_name}.etl_dag_orchestrator SUSPEND;
            
            To resume (restart scheduling):
              ALTER TASK {database_name}.{schema_name}.etl_dag_orchestrator RESUME;
        """).strip()
        
        return success_msg
        
    except Exception as e:
        return f"FAILED to create DAG: {str(e)}"

$$;

