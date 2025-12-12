CREATE OR REPLACE STORAGE INTEGRATION SML_AZURE_STORAGE_INTEGRATION
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = '<tenant_id_here>'
  STORAGE_ALLOWED_LOCATIONS = ('azure://<storage_account_name>.blob.core.windows.net/<container_name>/'); 

DESC INTEGRATION SML_AZURE_STORAGE_INTEGRATION;

SELECT SYSTEM$VALIDATE_STORAGE_INTEGRATION( 'SML_AZURE_STORAGE_INTEGRATION', 'azure://<storage_account_name>.blob.core.windows.net/<container_name>/', 'test.csv', 'read' )

CREATE OR REPLACE STAGE sml_azure_storage_stage
  STORAGE_INTEGRATION = SML_AZURE_STORAGE_INTEGRATION
  URL = 'azure://<storage_account_name>.blob.core.windows.net/<container_name>/'
  DIRECTORY = (ENABLE = TRUE);

ALTER STAGE sml_azure_storage_stage REFRESH;

LIST @sml_azure_storage_stage;