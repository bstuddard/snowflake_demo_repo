CREATE OR REPLACE PROCEDURE etl.table_updater(table_name VARCHAR, batch_id VARCHAR DEFAULT NULL, type_1_column_names VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import json
import uuid
from datetime import datetime
from functools import partial
from snowflake.snowpark.row import Row

class TableUpdater:
    def __init__(
        self,
        session,
        table_name: str,
        batch_id: str,
        database_name: str = 'learning_db',
        schema_name: str = 'dw',
        src_schema_name: str = 'src',
        etl_schema_name: str = 'etl',
        type_1_column_names: str | None = None

    ):
        """Updater class that upserts data from ETL view to data warehouse table.
        
        Supports dimension tables (Type 1 and Type 2 SCD) and fact tables.

        Args:
            session: Snowflake Snowpark session object
            table_name: Name of the target table (ETL view name will be inferred as vw_{table_name})
            batch_id: Batch ID for logging and traceability
            database_name: Target database name
            schema_name: Target schema name for dimension/fact tables
            src_schema_name: Source schema name (unused, kept for compatibility)
            etl_schema_name: Schema containing ETL views and staging tables
            type_1_column_names: Comma-separated list of Type 1 column names for Type 2 dimensions
                                 (enables historical row updates for these columns)
        """

        # Bind session for all future uses
        self.session = session

        # Setup logging helper - pre-fills procedure name, logger name, log level, and batch_id
        self._log_caller = partial(self.session.call, 'etl.logging', f'TABLE_UPDATER:{database_name}.{schema_name}.{table_name}', 'info', batch_id)
        self._log(f'Logger setup.')

        # Log initialization
        self._log(f'Starting class init variable infers.')

        # Infer base object names and calc audit columns
        self.table_name = table_name
        self.batch_id = batch_id
        self.database_name = database_name
        self.schema_name = schema_name
        self.etl_schema_name = etl_schema_name
        self.current_username = self.session.sql("SELECT CURRENT_USER() AS current_user").collect()[0][0]
        self.current_datetime_cst = self.session.sql("SELECT CONVERT_TIMEZONE('America/Los_Angeles', 'America/Chicago', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ AS current_time_cst").collect()[0][0]
        self.full_table_name = f'{database_name}.{schema_name}.{self.table_name}'
        self.etl_view_name = f'{database_name}.{etl_schema_name}.vw_{self.table_name}'
        self.table_primary_key_column_name = f'{self.table_name}_key'
        self.updates_table_name = f'{database_name}.{etl_schema_name}.{self.table_name}_updates'

        # Full Column Listing
        column_listing: list[Row] = self.session.sql(f"""
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE
            TABLE_CATALOG = UPPER('{database_name}')
        AND TABLE_SCHEMA = UPPER('{schema_name}')
        AND TABLE_NAME = UPPER('{self.table_name}')
        ORDER BY ORDINAL_POSITION;
        """).collect()
        column_listing = [row.COLUMN_NAME.lower() for row in column_listing]
        
        # Early validation: table must exist
        assert len(column_listing) > 0, f"Target table does not exist or has no columns: {self.full_table_name}"

        # Infer table type (including dimension SCD type)
        self.table_type = self._infer_table_type(column_listing)

        # Determine primary keys and join strings
        table_natural_keys_list: list[Row] = self.session.sql(f'SHOW PRIMARY KEYS IN TABLE {self.full_table_name}').collect()
        self.table_natural_keys_list = [row.column_name.lower() for row in table_natural_keys_list]
        self.natural_key_join_string = ' AND '.join([f'source.{natural_key_column_name} = target.{natural_key_column_name}' for natural_key_column_name in self.table_natural_keys_list])
        # Audit columns that are managed by the ETL process, not from source data
        self.audit_columns = ['create_username', 'create_datetime', 'create_batch_name', 'last_update_username', 'last_update_datetime', 'last_update_batch_name']
        self.update_table_columns = [column_name for column_name in column_listing if column_name not in (self.table_primary_key_column_name, *self.audit_columns)]
        self.insert_columns = [column_name for column_name in column_listing if column_name not in (self.table_primary_key_column_name)]
        
        # Type 2 SCD support for dimensions
        if self.table_type == 'dim_type_2':
            self.row_effective_date = self.current_datetime_cst.date()
            self.row_expiration_date_default = '9999-12-31'
            # Exclude Type 2 tracking columns from source selection (they don't exist in ETL views)
            type2_tracking_cols = ['row_effective_date', 'row_expiration_date', 'current_row_flag']
            self.source_select_columns = [col for col in self.update_table_columns if col not in type2_tracking_cols]
            # Exclude Type 2 tracking columns from update_hash_columns (they should only change via Type 2 processing)
            self.update_hash_columns = [column_name for column_name in column_listing if column_name not in (self.table_primary_key_column_name, 'create_username', 'create_datetime', 'create_batch_name') and column_name not in self.table_natural_keys_list and column_name not in type2_tracking_cols]
            # Type 1 columns for historical row updates (Kimball-correct behavior)
            self.type_1_column_names = type_1_column_names.split(',') if type_1_column_names else []
        else:
            self.source_select_columns = self.update_table_columns
            self.update_hash_columns = [column_name for column_name in column_listing if column_name not in (self.table_primary_key_column_name, 'create_username', 'create_datetime', 'create_batch_name') and column_name not in self.table_natural_keys_list]
            self.type_1_column_names = []  # Not applicable for non-Type 2 tables

        # Log all infers
        infers_parts = [
            f'table_name={self.table_name}',
            f'batch_id={self.batch_id}',
            f'database_name={self.database_name}',
            f'schema_name={self.schema_name}',
            f'etl_schema_name={self.etl_schema_name}',
            f'current_username={self.current_username}',
            f'current_datetime_cst={self.current_datetime_cst}',
            f'full_table_name={self.full_table_name}',
            f'etl_view_name={self.etl_view_name}',
            f'table_primary_key_column_name={self.table_primary_key_column_name}',
            f'updates_table_name={self.updates_table_name}',
            f'table_type={self.table_type}',
            f'table_natural_keys_list={self.table_natural_keys_list}',
            f'natural_key_join_string={self.natural_key_join_string}',
            f'update_table_columns={self.update_table_columns}',
            f'insert_columns={self.insert_columns}',
            f'source_select_columns={self.source_select_columns}',
            f'update_hash_columns={self.update_hash_columns}'
        ]
        # Add Type 2 specific fields if applicable
        if self.table_type == 'dim_type_2':
            infers_parts.extend([
                f'row_effective_date={self.row_effective_date}',
                f'row_expiration_date_default={self.row_expiration_date_default}',
                f'type_1_column_names={self.type_1_column_names}'
            ])
        self._log(f'Table infers completed: {" | ".join(infers_parts)}')

        # Perform validation checks
        self._perform_validation_checks(column_listing)


    def _perform_validation_checks(self, column_listing: list[str]) -> None:
        """Validate table structure and required columns exist.
        
        Args:
            column_listing: List of column names from the target table
            
        Raises:
            AssertionError: If any validation check fails
        """

        self._log(f'Performing validation checks for columns: {column_listing}')
        
        # Check that target table exists
        table_count = self.session.sql(f"""
            SELECT COUNT(*) as table_count 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_CATALOG = UPPER('{self.database_name}')
            AND TABLE_SCHEMA = UPPER('{self.schema_name}')
            AND TABLE_NAME = UPPER('{self.table_name}')
        """).collect()[0][0]
        assert table_count > 0, f"Target table does not exist: {self.full_table_name}"
        
        # Check that ETL view exists
        view_count = self.session.sql(f"""
            SELECT COUNT(*) as view_count 
            FROM INFORMATION_SCHEMA.VIEWS 
            WHERE TABLE_CATALOG = UPPER('{self.database_name}')
            AND TABLE_SCHEMA = UPPER('{self.etl_schema_name}')
            AND TABLE_NAME = UPPER('vw_{self.table_name}')
        """).collect()[0][0]
        assert view_count > 0, f"ETL view does not exist: {self.etl_view_name}"
        
        # Check natural keys exist (Issue #3 from review)
        assert len(self.table_natural_keys_list) > 0, f"No primary keys defined on table: {self.full_table_name}"
        
        # Check required columns exist on target table
        required_table_columns = ['etl_row_hash_value', 'create_username', 'create_datetime', 'create_batch_name', 'last_update_username', 'last_update_datetime', 'last_update_batch_name']
        for col in required_table_columns:
            assert col in column_listing, f"Required column '{col}' missing from table: {self.full_table_name}"
        
        # Check Type 2 tracking columns exist if Type 2 dimension
        if self.table_type == 'dim_type_2':
            type2_required_columns = ['etl_row_hash_value_2', 'row_effective_date', 'row_expiration_date', 'current_row_flag']
            for col in type2_required_columns:
                assert col in column_listing, f"Required Type 2 column '{col}' missing from table: {self.full_table_name}"
        
        # Check etl_row_hash_value exists in ETL view
        view_columns = self.session.sql(f"""
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_CATALOG = UPPER('{self.database_name}')
            AND TABLE_SCHEMA = UPPER('{self.etl_schema_name}')
            AND TABLE_NAME = UPPER('vw_{self.table_name}')
        """).collect()
        view_column_names = [row.COLUMN_NAME.lower() for row in view_columns]
        assert 'etl_row_hash_value' in view_column_names, f"Required column 'etl_row_hash_value' missing from view: {self.etl_view_name}"
        
        # Check etl_row_hash_value_2 exists in view if Type 2 dimension
        if self.table_type == 'dim_type_2':
            assert 'etl_row_hash_value_2' in view_column_names, f"Required column 'etl_row_hash_value_2' missing from view: {self.etl_view_name}"

        self._log(f'Column level validation completed.')

    def _log(self, message: str) -> None:
        """Print message to console and log to Snowflake logging procedure.
        
        Args:
            message: The message to print and log
        """
        print(message)
        self._log_caller(message)

    def _format_df_result(self, rows: list) -> str:
        """Format collected Snowpark rows as JSON string for logging.
        
        Args:
            rows: List of Snowpark Row objects from .collect()
            
        Returns:
            JSON string representation of the rows, or fallback message on error
        """
        try:
            return json.dumps([row.asDict() if hasattr(row, 'asDict') else dict(row) for row in rows])
        except:
            return 'likely completed successfully, but no rows.'

    def _infer_table_type(self, column_listing: list[str]) -> str:
        """Infer table type based on table name prefix and column structure.
        
        Args:
            column_listing (list): List of column names in lowercase
            
        Returns:
            str: 'dim_type_1' or 'dim_type_2' for dimension tables, 'fact' for fact tables
            
        Raises:
            ValueError: If table name doesn't start with 'dim_' or 'fact_'
        """
        table_lower = self.table_name.lower()
        if table_lower.startswith('dim_'):
            # Check if Type 2 dimension based on presence of etl_row_hash_value_2
            if 'etl_row_hash_value_2' in column_listing:
                return 'dim_type_2'
            else:
                return 'dim_type_1'
        elif table_lower.startswith('fact_'):
            return 'fact'
        else:
            raise ValueError(f"Unable to infer table type for '{self.table_name}'. Table name must start with 'dim_' or 'fact_'")


    def identify_upserts(self):
        """Create staging table identifying rows that need insert, update, or Type 2 change.
        
        Creates a temporary table ({table_name}_updates) containing:
        - New rows to insert (insert_update_indicator = 'insert')
        - Existing rows with changed Type 1 attributes (insert_update_indicator = 'update')
        - Existing rows with changed Type 2 attributes (insert_update_indicator = 'type2_change')
        
        Also logs change audit counts for monitoring.
        """
        # Build Type 2 tracking columns if needed
        if self.table_type == 'dim_type_2':
            type2_tracking_columns = f""",CASE 
                WHEN target.{self.table_primary_key_column_name} IS NULL THEN CAST('{self.row_effective_date}' AS DATE)
                WHEN source.etl_row_hash_value_2 <> target.etl_row_hash_value_2 THEN CAST('{self.row_effective_date}' AS DATE)
                ELSE target.row_effective_date
            END as row_effective_date
            ,CASE 
                WHEN target.{self.table_primary_key_column_name} IS NULL THEN CAST('{self.row_expiration_date_default}' AS DATE)
                WHEN source.etl_row_hash_value_2 <> target.etl_row_hash_value_2 THEN CAST('{self.row_expiration_date_default}' AS DATE)
                ELSE target.row_expiration_date
            END as row_expiration_date
            ,CASE 
                WHEN target.{self.table_primary_key_column_name} IS NULL THEN 1
                WHEN source.etl_row_hash_value_2 <> target.etl_row_hash_value_2 THEN 1
                ELSE target.current_row_flag
            END as current_row_flag"""
        else:
            type2_tracking_columns = ""
        
        sql_string = f"""
        CREATE OR REPLACE TABLE {self.updates_table_name} AS 
        SELECT
             target.{self.table_primary_key_column_name}
            ,{','.join([f'source.{col}' for col in self.source_select_columns])}
            {type2_tracking_columns}
            ,'{self.current_username}' as create_username
            ,CAST('{self.current_datetime_cst}' AS TIMESTAMP_NTZ) as create_datetime
            ,'{self.batch_id}' as create_batch_name
            ,'{self.current_username}' as last_update_username
            ,CAST('{self.current_datetime_cst}' AS TIMESTAMP_NTZ) as last_update_datetime
            ,'{self.batch_id}' as last_update_batch_name
            ,CASE 
                WHEN target.{self.table_primary_key_column_name} IS NULL THEN 'insert'
                {"WHEN source.etl_row_hash_value_2 <> target.etl_row_hash_value_2 THEN 'type2_change'" if self.table_type == 'dim_type_2' else ""}
                ELSE 'update'
             END as insert_update_indicator
        FROM {self.etl_view_name} source
        LEFT JOIN {self.full_table_name} target
            ON {self.natural_key_join_string}
                {"AND target.current_row_flag = 1" if self.table_type == 'dim_type_2' else ""}
        WHERE
            target.{self.table_primary_key_column_name} IS NULL
        OR source.etl_row_hash_value <> target.etl_row_hash_value
        {f"OR source.etl_row_hash_value_2 <> target.etl_row_hash_value_2" if self.table_type == 'dim_type_2' else ""}
        """
        self._log(f'upsert sql string: {sql_string}')
        execution_results = self.session.sql(sql_string).collect()
        self._log(f'upsert result: {self._format_df_result(execution_results)}')

        change_audit_sql_string = f"""
        SELECT
             COALESCE(SUM(CASE WHEN insert_update_indicator = 'insert' THEN 1 ELSE 0 END), 0) AS new_records
            ,COALESCE(SUM(CASE WHEN insert_update_indicator = 'update' THEN 1 ELSE 0 END), 0) AS change_records
            ,COALESCE(SUM(CASE WHEN insert_update_indicator = 'type2_change' THEN 1 ELSE 0 END), 0) AS type2_changes
        FROM {self.updates_table_name}
        """
        self._log(f'change audit sql string: {change_audit_sql_string}')
        execution_results = self.session.sql(change_audit_sql_string).collect()
        self._log(f'change audit result: {self._format_df_result(execution_results)}')


    def _process_type2_expirations(self):
        """Expire current records that have Type 2 changes.
        
        For rows marked as 'type2_change' in the staging table, sets:
        - row_expiration_date to yesterday
        - current_row_flag to 0
        - Updates audit columns (last_update_*)
        
        Only runs for dim_type_2 tables.
        """
        if self.table_type != 'dim_type_2':
            return
        
        sql_string = f"""
        MERGE INTO {self.full_table_name} as target
        USING {self.updates_table_name} as source
        ON source.{self.table_primary_key_column_name} = target.{self.table_primary_key_column_name}
        WHEN MATCHED AND source.insert_update_indicator = 'type2_change'
        THEN UPDATE SET
             target.row_expiration_date = CAST('{self.row_effective_date}' AS DATE) - 1
            ,target.current_row_flag = 0
            ,target.last_update_username = '{self.current_username}'
            ,target.last_update_datetime = CAST('{self.current_datetime_cst}' AS TIMESTAMP_NTZ)
            ,target.last_update_batch_name = '{self.batch_id}'
        """
        self._log(f'type2 expirations sql string: {sql_string}')
        execution_results = self.session.sql(sql_string).collect()
        self._log(f'type2 expirations result: {self._format_df_result(execution_results)}')


    def _process_type1_historical_updates(self) -> None:
        """Update historical rows to match current row for Type 1 columns.
        
        For Type 2 dimensions, Type 1 changes should propagate to all historical rows.
        Compares historical rows (current_row_flag = 0) against the current row 
        (current_row_flag = 1) using etl_row_hash_value to detect differences.
        
        Only runs if:
        - Table is dim_type_2
        - type_1_column_names was provided during initialization
        """
        if self.table_type != 'dim_type_2' or not self.type_1_column_names:
            return

        sql_string = f"""
        MERGE INTO {self.full_table_name} as target
        USING (
            SELECT * FROM {self.full_table_name} 
            WHERE current_row_flag = 1
        ) as source
        ON {self.natural_key_join_string}
            AND target.current_row_flag = 0
        WHEN MATCHED AND source.etl_row_hash_value <> target.etl_row_hash_value
        THEN UPDATE SET
        {', '.join([f'target.{column_name} = source.{column_name}' for column_name in self.type_1_column_names])}
        ,target.etl_row_hash_value = source.etl_row_hash_value
        ,target.last_update_username = '{self.current_username}'
        ,target.last_update_datetime = CAST('{self.current_datetime_cst}' AS TIMESTAMP_NTZ)
        ,target.last_update_batch_name = '{self.batch_id}'
        """
        self._log(f'table type 2 historical type 1 updates: {sql_string}')
        execution_results = self.session.sql(sql_string).collect()
        self._log(f'table type 2 historical type 1 updates result: {self._format_df_result(execution_results)}')


    def process_table_updates(self):
        """Process all UPDATE operations from the staging table.
        
        For Type 2 dimensions, this includes:
        1. Expiring current rows that have Type 2 changes
        2. Updating current rows with Type 1 changes
        
        Note: Type 1 historical updates are handled in process_table_inserts() AFTER
        new rows are inserted, so the current row values are available.
        
        For other table types, simply updates rows marked as 'update'.
        """
        # Handle Type 2 expirations first (if applicable)
        if self.table_type == 'dim_type_2':
            self._process_type2_expirations()
        
        sql_string = f"""
        MERGE INTO {self.full_table_name} as target
        USING {self.updates_table_name} as source
        ON source.{self.table_primary_key_column_name} = target.{self.table_primary_key_column_name}
        WHEN MATCHED AND source.insert_update_indicator = 'update'
        THEN UPDATE SET
        {', '.join([f'target.{column_name} = source.{column_name}' for column_name in self.update_hash_columns])}
        """
        self._log(f'table updates sql string: {sql_string}')
        execution_results = self.session.sql(sql_string).collect()
        self._log(f'table updates result: {self._format_df_result(execution_results)}')


    def process_table_inserts(self):
        """Insert new rows from the staging table.
        
        Inserts rows marked as:
        - 'insert': Completely new records
        - 'type2_change': New version of record for Type 2 dimension changes
        
        For Type 2 dimensions, also updates historical rows with Type 1 changes
        AFTER inserts complete (so the current row values are available).
        """
        sql_string = f"""
        MERGE INTO {self.full_table_name} as target
        USING {self.updates_table_name} as source
        ON {self.natural_key_join_string}
            {"AND target.current_row_flag = 1" if self.table_type == 'dim_type_2' else ""}
        WHEN NOT MATCHED AND source.insert_update_indicator IN ('insert', 'type2_change')
        THEN INSERT ({', '.join(self.insert_columns)})
        VALUES ({', '.join([f'source.{col}'for col in self.insert_columns])})
        """
        self._log(f'table inserts sql string: {sql_string}')
        execution_results = self.session.sql(sql_string).collect()
        self._log(f'table inserts result: {self._format_df_result(execution_results)}')

        # Type 1 historical updates must run AFTER inserts so the new current row exists
        if self.table_type == 'dim_type_2':
            self._process_type1_historical_updates()
        
        
def main(session, table_name: str, batch_id: str | None = None, type_1_column_names: str | None = None) -> str:
    """Entry point for Snowflake stored procedure.
    
    Args:
        session: Snowflake Snowpark session
        table_name: Name of the target table to update
        batch_id: Optional batch ID for traceability (auto-generated if not provided)
        type_1_column_names: Optional comma-separated Type 1 column names for Type 2 dimensions
        
    Returns:
        Summary string with insert/update/type2_change counts
        
    Raises:
        Exception: Re-raises any exception after logging
    """
    # Generate batch_id if not provided
    if batch_id is None:
        batch_id = f"{table_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
    
    try:
        updater = TableUpdater(session, table_name, batch_id, type_1_column_names=type_1_column_names)
        updater.identify_upserts()
        updater.process_table_updates()
        updater.process_table_inserts()

        # Return a nice summary
        summary = session.sql(f"""
            SELECT 
                COALESCE(SUM(CASE WHEN insert_update_indicator = 'insert' THEN 1 ELSE 0 END),0) || ' inserts, ' ||
                COALESCE(SUM(CASE WHEN insert_update_indicator = 'update' THEN 1 ELSE 0 END),0) || ' updates, ' ||
                COALESCE(SUM(CASE WHEN insert_update_indicator = 'type2_change' THEN 1 ELSE 0 END),0) || ' type2 changes'
            FROM {updater.database_name}.{updater.etl_schema_name}.{table_name}_updates
        """).collect()[0][0]
        updater._log(f'Completed, summary: {summary}')
        
        return f"{table_name} completed — {summary}"
    except Exception as e:
        # Log the error before raising
        try:
            session.call('etl.logging', f'TABLE_UPDATER:{table_name}', 'error', batch_id, f'Error updating {table_name}: {str(e)}')
        except:
            pass  # Don't fail if logging itself fails
        raise e
    
$$;