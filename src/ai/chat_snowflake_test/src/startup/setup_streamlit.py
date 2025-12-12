import os
import logging


# Setup module for logging
logger = logging.getLogger(__name__)


def _initialize_session_state(streamlit_instance):
    """Initialize basic session state variables.
    
    Args:
        streamlit_instance: Streamlit instance
    """
    if 'visibility' not in streamlit_instance.session_state:
        streamlit_instance.session_state.visibility = 'visible'
        streamlit_instance.session_state.disabled = False


def _load_css_styles(streamlit_instance):
    """Load custom CSS styles from assets folder.
    
    Args:
        streamlit_instance: Streamlit instance
    """
    with open('src/assets/styles.css') as main_css:
        streamlit_instance.markdown(f'<style>{main_css.read()}</style>', unsafe_allow_html=True)
    # Logo example: streamlit_instance.logo('src/assets/website_logo.png', size='large')


def _setup_app_header(streamlit_instance, app_title: str):
    """Set up main app title and header.
    
    Args:
        streamlit_instance: Streamlit instance
        app_title: Title of the app to display
    """
    streamlit_instance.title(app_title)


def _setup_sidebar(streamlit_instance, app_information: str):
    """Configure sidebar with app info, user info, and controls.
    
    Args:
        streamlit_instance: Streamlit instance
        app_information: More detailed descriptive info
    """
    with streamlit_instance.sidebar:
        streamlit_instance.write(app_information)
        streamlit_instance.write(f"Logged in as: {streamlit_instance.context.headers.get('x-forwarded-email')}")

        # Reset chat
        if streamlit_instance.button("New Chat"):
            streamlit_instance.session_state.messages = []
            streamlit_instance.session_state.graph_state = {'messages': []}
            streamlit_instance.rerun()


def _initialize_chat_history(streamlit_instance):
    """Initialize chat-specific session state.
    
    Args:
        streamlit_instance: Streamlit instance
    """
    if 'messages' not in streamlit_instance.session_state:
        streamlit_instance.session_state.messages = []
    if 'graph_state' not in streamlit_instance.session_state:
        streamlit_instance.session_state.graph_state = {'messages': []}


def setup_streamlit_app(
    streamlit_instance,
    app_title: str,
    app_information: str,
    initial_user_instructions: str,
):
    """Setup streamlit app with defaults. Main orchestrator function.

    Args:
        streamlit_instance: Streamlit instance
        app_title: Title of the app to display
        app_information: More detailed descriptive info
        initial_user_instructions: User instructions on first chat
    """
    _initialize_session_state(streamlit_instance)
    _load_css_styles(streamlit_instance)
    _setup_app_header(streamlit_instance, app_title)
    _setup_sidebar(streamlit_instance, app_information)
    streamlit_instance.write(initial_user_instructions)
    _initialize_chat_history(streamlit_instance)