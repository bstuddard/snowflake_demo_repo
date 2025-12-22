import os
from snowflake.snowpark import Session
from snowflake.snowpark.context import get_active_session

# Attempt to get various env variables
SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_HOST = os.getenv("SNOWFLAKE_HOST")
SNOWFLAKE_DATABASE = os.getenv("SNOWFLAKE_DATABASE")
SNOWFLAKE_SCHEMA = os.getenv("SNOWFLAKE_SCHEMA")
SNOWFLAKE_USER = os.getenv("SNOWFLAKE_USER")
SNOWFLAKE_ROLE = os.getenv("SNOWFLAKE_ROLE")
SNOWFLAKE_WAREHOUSE = os.getenv("SNOWFLAKE_WAREHOUSE")


def get_session_via_keypair():
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import serialization

    key_path = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH")
    key_path_2 = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH_2")
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE")
    password = passphrase.encode() if passphrase else None

    # Load private key
    try:
        with open(key_path, "rb") as key_file:
            private_key = serialization.load_pem_private_key(
                key_file.read(),
                password=password,
                backend=default_backend()
            )
    except:
        with open(key_path_2, "rb") as key_file:
            private_key = serialization.load_pem_private_key(
                key_file.read(),
                password=password,
                backend=default_backend()
            )

    # Convert to bytes format Snowflake expects
    pkb = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )

    # Create connection parameters
    connection_parameters = {
        "account": SNOWFLAKE_ACCOUNT,
        "user": SNOWFLAKE_USER,
        "role": SNOWFLAKE_ROLE,
        "database": SNOWFLAKE_DATABASE,
        "schema": SNOWFLAKE_SCHEMA,
        "warehouse": SNOWFLAKE_WAREHOUSE,
        "private_key": pkb
    }

    return connection_parameters


def get_session() -> Session:
    """Get a session via various method attempts to handle different runtime environments.

    Returns:
        Session: Snowflake session.
    """

    try:
        return get_active_session()
    except Exception as e:
        return Session.builder.configs(get_session_via_keypair()).create()

    