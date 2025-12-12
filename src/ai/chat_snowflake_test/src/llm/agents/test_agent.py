from langgraph.types import Command
from typing import Literal
from langchain_core.messages import AIMessage, SystemMessage
from snowflake.snowpark import Session
from src.startup.connections import *
from src.llm.model import get_model


def test_agent(state) -> Command[Literal['__end__']]:
    """Test agent that returns a simple AI message.
    
    Args:
        state: Current graph state containing messages
        
    Returns:
        Command to end the graph with a test AI message
    """
    model, session = get_model()

    messages = [
        SystemMessage('You are a helpful AI assistant'),
        *state['messages']
    ]
    output = model.invoke(messages)
    session.close()

    return Command(
        goto='__end__',
        update={'messages': output}
    )