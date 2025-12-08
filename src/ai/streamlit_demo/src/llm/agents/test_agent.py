from langgraph.types import Command
from typing import Literal
from langchain_core.messages import AIMessage


def test_agent(state) -> Command[Literal['__end__']]:
    """Test agent that returns a simple AI message.
    
    Args:
        state: Current graph state containing messages
        
    Returns:
        Command to end the graph with a test AI message
    """
    return Command(
        goto='__end__',
        update={'messages': AIMessage('test ai message')}
    )