"""
ETL DAG Orchestrator

Creates a DAG that orchestrates ETL loads in dependency order:
1. dim_employee (runs first)
2. fact_employee_pay (runs after dim_employee succeeds)

Usage:
    Copy this code into a Snowflake Python worksheet or notebook cell,
    adjust the configuration variables, and run.
"""

from snowflake.snowpark import Session
from snowflake.core.task.dagv1 import DAG, DAGTask, DAGOperation
from snowflake.core import CreateMode, Root

# =============================================================================
# Configuration - adjust these values for your environment
# =============================================================================
TARGET_DATABASE = 'LEARNING_DB'
TARGET_SCHEMA = 'ETL'
WAREHOUSE_NAME = 'COMPUTE_WH'

# Set to number of minutes for automatic scheduling, or None for manual execution only
SCHEDULE_MINUTES = None  # e.g., 60 for hourly runs


def create_dag_orchestrator(session: Session) -> str:
    """
    Creates and deploys the ETL DAG orchestrator.
    
    Args:
        session: Snowflake session object (use get_active_session() in notebooks)
    
    Returns:
        Success message with DAG details
    """
    root = Root(session)
    
    # Build DAG configuration
    dag_config = {
        'name': 'etl_dag_orchestrator',
        'warehouse': WAREHOUSE_NAME
    }
    
    # Add schedule if configured
    if SCHEDULE_MINUTES:
        dag_config['schedule'] = f'{SCHEDULE_MINUTES} MINUTE'
    
    # Define the DAG with tasks and dependencies
    with DAG(**dag_config) as dag:
        # Task 1: Load dim_employee (runs first)
        task_dim_employee = DAGTask(
            name="load_dim_employee",
            definition=f"CALL {TARGET_DATABASE}.{TARGET_SCHEMA}.table_updater('dim_employee');",
            comment="Load dimension table: dim_employee"
        )
        
        # Task 2: Load fact_employee_pay (depends on dim_employee)
        task_fact_employee_pay = DAGTask(
            name="load_fact_employee_pay",
            definition=f"CALL {TARGET_DATABASE}.{TARGET_SCHEMA}.table_updater('fact_employee_pay');",
            comment="Load fact table: fact_employee_pay"
        )
        
        # Define dependency: fact_employee_pay waits for dim_employee to succeed
        task_dim_employee >> task_fact_employee_pay
    
    # Deploy the DAG
    dag_op = DAGOperation(root.databases[TARGET_DATABASE].schemas[TARGET_SCHEMA])
    dag_op.deploy(dag, mode=CreateMode.or_replace)
    
    schedule_msg = f" (scheduled every {SCHEDULE_MINUTES} minutes)" if SCHEDULE_MINUTES else " (manual execution only)"
    return f"DAG 'etl_dag_orchestrator' deployed to {TARGET_DATABASE}.{TARGET_SCHEMA}{schedule_msg}"


def execute_dag(session: Session) -> str:
    """Manually trigger the DAG execution."""
    root = Root(session)
    tasks = root.databases[TARGET_DATABASE].schemas[TARGET_SCHEMA].tasks
    dag_task = tasks['etl_dag_orchestrator']
    dag_task.execute()
    return "DAG execution triggered!"


# =============================================================================
# Main execution (for use in Snowflake notebooks/worksheets)
# =============================================================================
if __name__ == "__main__":
    # In a Snowflake notebook, get_active_session() is available globally
    session = get_active_session()
    
    # Deploy the DAG
    result = create_dag_orchestrator(session)
    print(result)
    
    # Uncomment to execute immediately after deployment:
    # print(execute_dag(session))
    
    # View task history with this SQL:
    # SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'etl_dag_orchestrator')) 
    # ORDER BY SCHEDULED_TIME DESC;

