import os
from langchain_core.messages import HumanMessage
from src.llm.graph import graph


def _display_message_history(streamlit_instance):
    """Display all past messages in the chat interface.
    
    Args:
        streamlit_instance: Streamlit instance
    """
    for message in streamlit_instance.session_state.messages:
        with streamlit_instance.chat_message(message['role']):
            streamlit_instance.write(message['content'])


def _accept_user_input(streamlit_instance):
    """Accept user input, process through graph, and display assistant response.
    
    Handles adding user message to state, invoking the graph for processing,
    extracting results, and displaying the assistant's response.
    
    Args:
        streamlit_instance: Streamlit instance
    """
    if user_input := streamlit_instance.chat_input('Ask a question'):

        # Add to display and graph history
        streamlit_instance.session_state.messages.append({'role': 'user', 'content': user_input})
        streamlit_instance.session_state.graph_state['messages'].append(HumanMessage(user_input))
        with streamlit_instance.chat_message('user'):
            streamlit_instance.write(user_input)

        # Query graph
        with streamlit_instance.spinner('Processing question'):
            graph_result = graph.invoke(streamlit_instance.session_state.graph_state)

        # Save off persistent keys
        persistent_keys = ['messages']
        for key in persistent_keys:
            streamlit_instance.session_state.graph_state[key] = graph_result[key]
        assistant_response = graph_result['messages'][-1].content
        with streamlit_instance.chat_message('assistant'):
            streamlit_instance.write(assistant_response)
        
        # Add assistant response to history
        streamlit_instance.session_state.messages.append({'role': 'assistant', 'content': assistant_response})


def display_streamlit_chat(streamlit_instance):
    """Display and manage the chat interface with message history and user input.
    
    Main orchestrator that displays message history and handles user input.
    
    Args:
        streamlit_instance: Streamlit instance
    """
    _display_message_history(streamlit_instance)
    _accept_user_input(streamlit_instance)