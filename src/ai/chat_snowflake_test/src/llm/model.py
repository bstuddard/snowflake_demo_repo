from snowflake.snowpark import Session
from langchain_snowflake import ChatSnowflake
from src.startup.connections import get_connection_params


def get_model() -> tuple:
    """Create and return a ChatSnowflake model instance.

    Args:
        session: Snowflake session to use for the model

    Returns:
        tuple of ChatSnowflake, Session
    """
    session = Session.builder.configs(get_connection_params()).create()
    model = ChatSnowflake(
        session=session,
        model="CLAUDE-3-7-SONNET",
        temperature=0.1
    )
    return model, session