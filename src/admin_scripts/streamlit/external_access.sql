CREATE OR REPLACE NETWORK RULE pypi_network_rule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('pypi.org:443',           -- HTTPS access to PyPI
                  'files.pythonhosted.org:443'); -- HTTPS access to PyPI files


-- Create external access integration for package downloads
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION pypi_external_access_integration
    ALLOWED_NETWORK_RULES = (pypi_network_rule)
    ENABLED = TRUE;