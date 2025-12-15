import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Setup logging for module
logger = logging.getLogger(__name__)
logger.info('Logging setup')

from src.startup.load_config import *
from src.startup.connections import *

import os
import logging
import streamlit as st
from src.startup.setup_streamlit import *
from src.llm.chat import display_streamlit_chat
from src.startup.load_data import *

# Boilerplate setup
setup_streamlit_app(
    streamlit_instance=st,
    app_title='Test App',
    app_information='Test App Info',
    initial_user_instructions='Instructions'
)
logger.info('setup completed')

test_connection()
test_chat_snowflake_connection()

display_streamlit_chat(st)