import os
import logging
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from snowflake.snowpark import Session
from langchain_snowflake import ChatSnowflake


logger = logging.getLogger(__name__)


# Environment variables below will be automatically populated by Snowflake.
SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_HOST = os.getenv("SNOWFLAKE_HOST")
SNOWFLAKE_DATABASE = os.getenv("SNOWFLAKE_DATABASE")
SNOWFLAKE_SCHEMA = os.getenv("SNOWFLAKE_SCHEMA")

# Custom environment variables
SNOWFLAKE_USER = os.getenv("SNOWFLAKE_USER")
SNOWFLAKE_ROLE = os.getenv("SNOWFLAKE_ROLE")
SNOWFLAKE_WAREHOUSE = os.getenv("SNOWFLAKE_WAREHOUSE")


def get_session_via_keypair():
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
    


def get_login_token():
    """
    Read the login token supplied automatically by Snowflake. These tokens
    are short lived and should always be read right before creating any new connection.
    """
    with open("/snowflake/session/token", "r") as f:
        return f.read()


def get_connection_params():
    """
    Construct Snowflake connection params from environment variables.
    """
    if os.path.exists("/snowflake/session/token"):
        # Running inside Snowflake - use OAuth token
        return {
            "account": SNOWFLAKE_ACCOUNT,
            "host": SNOWFLAKE_HOST,
            "authenticator": "oauth",
            "token": get_login_token(),
            "warehouse": SNOWFLAKE_WAREHOUSE,
            "database": SNOWFLAKE_DATABASE,
            "schema": SNOWFLAKE_SCHEMA
        }
    else:
        # Use traditional keypair for local development
        return get_session_via_keypair()


def test_connection():
    # Start a Snowflake session, run the query and write results to specified table
    with Session.builder.configs(get_connection_params()).create() as session:
        logger.info("Test started")
        # Print out current session context information.
        database = session.get_current_database()
        schema = session.get_current_schema()
        warehouse = session.get_current_warehouse()
        role = session.get_current_role()
        user = session.get_current_user()
        logger.info(
            f"Connection succeeded. Current session context: user={user}, database={database}, schema={schema}, warehouse={warehouse}, role={role}"
        )


def test_chat_snowflake_connection():
    with Session.builder.configs(get_connection_params()).create() as session:
        # Explicitly activate the warehouse for Cortex calls
        session.sql("USE WAREHOUSE container_warehouse").collect()

        model = ChatSnowflake(
            session=session, model="CLAUDE-3-7-SONNET", temperature=0.1, max_tokens=500
        )
        output = model.invoke('What is 2+2?')
        print(f'Response: {output.content}')


def test_chat_snowflake_connection_streamlit_native():
    """Streamlit running directly on a container compute pool will use a simpler auth method.
    This is probably an ideal setup as it gets around having to publish up docker images.
    """

    import streamlit as st

    st.connection("snowflake").reset()
    conn = st.connection("snowflake")
    session_instance = conn.session()
    
    with session_instance as session:
        logger.info("Test started")
        # Print out current session context information.
        database = session.get_current_database()
        schema = session.get_current_schema()
        warehouse = session.get_current_warehouse()
        role = session.get_current_role()
        user = session.get_current_user()
        logger.info(
            f"Connection succeeded. Current session context: user={user}, database={database}, schema={schema}, warehouse={warehouse}, role={role}"
        )

        # Explicitly activate the warehouse for Cortex calls
        session.sql("USE WAREHOUSE container_warehouse").collect()

        model = ChatSnowflake(
            session=session, model="CLAUDE-3-7-SONNET", temperature=0.1, max_tokens=500
        )
        output = model.invoke('What is 2+2?')
        print(f'Response: {output.content}')