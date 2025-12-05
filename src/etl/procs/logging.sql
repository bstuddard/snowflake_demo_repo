CREATE OR REPLACE PROCEDURE etl.logging(
    logger_name VARCHAR,
    log_level VARCHAR,
    batch_id VARCHAR,
    log_message VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import logging

def main(session, logger_name: str, log_level: str, batch_id: str, log_message: str) -> str:
    """
    Production logging procedure for ETL processes.
    
    Args:
        session: Snowflake session object
        logger_name: Name of the logger (appears in Scope field for filtering)
        log_level: Log level - 'info' or 'error' (case-insensitive)
        batch_id: Batch ID for traceability (will be prepended to message)
        log_message: The message to log
    
    Returns:
        Success message confirming the log was written

    Examples:
        --Using this proc
        CALL etl.logging('logger_name_example', 'info', 'batch_123', 'log_message text');
        CALL etl.logging('logger_name_example', 'error', 'batch_123', 'log_message text error');

        --Reviewing log results
        SELECT * 
        FROM LEARNING_DB.ETL.CUSTOM_EVENTS 
        WHERE 
            RECORD_TYPE = 'LOG'
        AND VALUE LIKE '[ETL]%'
        ORDER BY TIMESTAMP DESC
    """
    # Get logger with custom name for filtering
    logger = logging.getLogger(logger_name)
    
    # Normalize log level to lowercase
    log_level_lower = log_level.lower() if log_level else 'info'
    
    # Format message with batch_id prefix and ETL prefix
    formatted_message = f"[ETL] batch_id: {batch_id} - {log_message}"
    
    # Log based on level
    if log_level_lower == 'error':
        logger.error(formatted_message)
        return f"Error log written: {log_message}"
    else:
        logger.info(formatted_message)
        return f"Info log written: {log_message}"
$$;

