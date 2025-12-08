# Only needed locally for env file
from src.startup.load_config import *

import os
import logging
import streamlit as st
from src.startup.setup_streamlit import *
from src.llm.chat import display_streamlit_chat
from src.startup.load_data import *

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Boilerplate setup
setup_streamlit_app(
    streamlit_instance=st,
    app_title='Test App',
    app_information='Test App Info',
    initial_user_instructions='Instructions'
)
logger.info('setup completed')

display_streamlit_chat(st)