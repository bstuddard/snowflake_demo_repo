CREATE OR REPLACE PROCEDURE etl.table_updater(table_name VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
from snowflake.snowpark.row import Row

class TableUpdater:
    def __init__(
        self,
        session,
        table_name: str,
        database_name = 'learning_db',
        schema_name = 'dw',
        src_schema_name = 'src',
        etl_schema_name = 'etl'

    ):
        """Updater class that upserts data from etl view to edw table

        Args:
            session: Snowflake session object
            table_name (str): Name of the table (view name will be inferred)
        """

        # Infer base object names and calc audit columns
        self.session = session
        self.table_name = table_name
        self.database_name = database_name
        self.schema_name = schema_name
        self.etl_schema_name = etl_schema_name
        self.current_username = 'demo_user' # in actual env: self.session.sql("SELECT CURRENT_USER() AS current_user").collect()[0][0]
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

        # Determine primary keys and join strings
        table_natural_keys_list: list[Row] = self.session.sql(f'SHOW PRIMARY KEYS IN TABLE {self.full_table_name}').collect()
        self.table_natural_keys_list = [row.column_name.lower() for row in table_natural_keys_list]
        self.natural_key_join_string = ' AND '.join([f'source.{natural_key_column_name} = target.{natural_key_column_name}' for natural_key_column_name in self.table_natural_keys_list])
        self.update_table_columns = [column_name for column_name in column_listing if column_name not in (self.table_primary_key_column_name, 'create_username', 'create_datetime', 'last_update_username', 'last_update_datetime')]
        self.insert_columns = [column_name for column_name in column_listing if column_name not in (self.table_primary_key_column_name)]
        self.update_hash_columns = [column_name for column_name in column_listing if column_name not in (self.table_primary_key_column_name, 'create_username', 'create_datetime') and column_name not in self.table_natural_keys_list]


    def identify_upserts(self):
        sql_string = f"""
        CREATE OR REPLACE TABLE {self.updates_table_name} AS 
        SELECT
             target.{self.table_primary_key_column_name}
            ,{','.join([f'source.{col}' for col in self.update_table_columns])}
            ,'{self.current_username}' as create_username
            ,CAST('{self.current_datetime_cst}' AS TIMESTAMP_NTZ) as create_datetime
            ,'{self.current_username}' as last_update_username
            ,CAST('{self.current_datetime_cst}' AS TIMESTAMP_NTZ) as last_update_datetime
            ,CASE 
                WHEN target.{self.table_primary_key_column_name} IS NULL THEN 'insert'
                ELSE 'update'
             END as insert_update_indicator
        FROM {self.etl_view_name} source
        LEFT JOIN {self.full_table_name} target
            ON {self.natural_key_join_string}
        WHERE
            target.{self.table_primary_key_column_name} IS NULL
        OR source.etl_row_hash_value <> target.etl_row_hash_value
        """
        print(sql_string)
        execution_results = self.session.sql(sql_string)
        execution_results.show()

        change_audit_sql_string = f"""
        SELECT
             SUM(CASE WHEN insert_update_indicator = 'insert' THEN 1 ELSE 0 END) AS new_records
            ,SUM(CASE WHEN insert_update_indicator = 'update' THEN 1 ELSE 0 END) AS change_records
        FROM {self.updates_table_name}
        """
        print(change_audit_sql_string)
        self.session.sql(change_audit_sql_string).show()


    def process_table_updates(self):
        
        sql_string = f"""
        MERGE INTO {self.full_table_name} as target
        USING {self.updates_table_name} as source
        ON source.{self.table_primary_key_column_name} = target.{self.table_primary_key_column_name}
        WHEN MATCHED AND source.insert_update_indicator = 'update'
        THEN UPDATE SET
        {', '.join([f'target.{column_name} = source.{column_name}' for column_name in self.update_hash_columns])}
        """
        print(sql_string)
        execution_results = self.session.sql(sql_string)
        execution_results.show()


    def process_table_inserts(self):
        
        sql_string = f"""
        MERGE INTO {self.full_table_name} as target
        USING {self.updates_table_name} as source
        ON {self.natural_key_join_string}
        WHEN NOT MATCHED AND source.insert_update_indicator = 'insert'
        THEN INSERT ({', '.join(self.insert_columns)})
        VALUES ({', '.join([f'source.{col}'for col in self.insert_columns])})
        """
        print(sql_string)
        execution_results = self.session.sql(sql_string)
        execution_results.show()
        
        
def main(session, table_name: str) -> str:

    try:
        updater = TableUpdater(session, table_name)
        updater.identify_upserts()
        updater.process_table_updates()
        updater.process_table_inserts()

        # Return a nice summary
        summary = session.sql(f"""
            SELECT 
                COALESCE(SUM(CASE WHEN insert_update_indicator = 'insert' THEN 1 ELSE 0 END),0) || ' inserts, ' ||
                COALESCE(SUM(CASE WHEN insert_update_indicator = 'update' THEN 1 ELSE 0 END),0) || ' updates'
            FROM {updater.database_name}.{updater.etl_schema_name}.{table_name}_updates
        """).collect()[0][0]
        
        return f"{table_name} completed — {summary}"
    except Exception as e:
        return f"FAILED: {table_name} - {str(e)}"
    
$$;