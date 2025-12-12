# This is where you can do any data loading, sql queries, etc that should be completed on startup

import logging


# Setup logging for module
logger = logging.getLogger(__name__)


def load_data_example() -> str:
    """Example function for loading data on startup.
    
    Replace this with actual data loading logic (SQL queries, API calls, etc.)
    
    Returns:
        str: Example test string
    """
    return "Test str"


load_data_example()