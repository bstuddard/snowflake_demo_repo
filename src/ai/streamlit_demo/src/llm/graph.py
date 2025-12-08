import streamlit as st
from langgraph.graph import StateGraph, MessagesState, START, END
from src.llm.agents.test_agent import test_agent

@st.cache_resource
def build_graph():
    """Build and compile the LangGraph state graph with all agents and edges.
    
    Cached to avoid rebuilding the graph on every streamlit rerun.
    
    Returns:
        Compiled StateGraph instance ready for invocation
    """
    # Nodes
    builder = StateGraph(state_schema=MessagesState)
    for node_name, node_function in [
        ('test_agent', test_agent)
    ]:
        builder.add_node(node_name, node_function)
    
    # Edges
    builder.add_edge(START, 'test_agent')
    
    graph = builder.compile()
    return graph

graph = build_graph()