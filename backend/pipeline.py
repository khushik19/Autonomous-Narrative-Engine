# pipeline.py
# This file connects all 3 agents together
# It passes output of one agent as input to next agent

import os
import json
import uuid

# Each request gets a unique ID
# So multiple users can generate at same time
def get_temp_path(request_id: str, filename: str) -> str:
    folder = f"temp/{request_id}"
    os.makedirs(folder, exist_ok=True)
    return f"{folder}/{filename}"


def run_pipeline(
    topic: str,
    template_id: str = "Bold Text and Color Morph Product Launch Presentation",
    custom_template_path: str = None
) -> str:
    """
    Runs all 3 agents in order
    Returns path to final .pptx file
    
    topic:                what user typed
    template_id:          which built-in template to use
    custom_template_path: path to uploaded .pptx (if user uploaded one)
    """
    
    # Unique ID for this request
    request_id = str(uuid.uuid4())[:8]
    print(f"\n{'='*50}")
    print(f"Request ID: {request_id}")
    print(f"Topic: {topic}")
    print(f"{'='*50}")
    
    
    # ─────────────────────────────────────
    # STEP 1 — RESEARCH AGENT
    # Input:  topic string
    # Output: research.txt file
    # ─────────────────────────────────────
    
    print("\n[1/3] Running Research Agent...")
    
    # Path where research agent will save its output
    research_output_path = get_temp_path(request_id, "research.txt")
    
    # Import and run research agent
    import agents.research_agent as research_agent
    
    # Call their function
    research_agent.run(
        topic       = topic,
        output_path = research_output_path
    )
    
    # Make sure file was created
    if not os.path.exists(research_output_path):
        raise Exception("Research agent did not create research.txt")
    
    print(f"Research done. File saved: {research_output_path}")
    
    
    # ─────────────────────────────────────
    # STEP 2 — COPYWRITER AGENT
    # Input:  research.txt file
    # Output: content.json file
    # ─────────────────────────────────────
    
    print("\n[2/3] Running Copywriter Agent...")
    
    # Path where copywriter agent will save its output
    content_output_path = get_temp_path(request_id, "content.json")
    
    # Import and run copywriter agent
    import agents.copywriter_agent as copywriter_agent
    
    # Call their function
    copywriter_agent.run(
        input_path  = research_output_path,
        output_path = content_output_path
    )
    
    # Make sure file was created
    if not os.path.exists(content_output_path):
        raise Exception("Copywriter agent did not create content.json")
    
    print(f"Content written. File saved: {content_output_path}")
    
    
    # ─────────────────────────────────────
    # STEP 3 — VISUAL DESIGNER AGENT
    # Input:  content.json file
    # Output: presentation.pptx file
    # ─────────────────────────────────────
    
    print("\n[3/3] Running Visual Designer Agent...")
    
    # Read the content.json that copywriter made
    with open(content_output_path, "r") as f:
        content_json = json.load(f)
    
    # Path for final output
    pptx_output_path = get_temp_path(request_id, "presentation.pptx")
    
    # Import and run visual agent
    import agents.visual_agent as visual_agent
    
    visual_agent.run(
        content_json         = content_json,
        output_path          = pptx_output_path,
        template_id          = template_id,
        custom_template_path = custom_template_path
    )
    
    # Make sure file was created
    if not os.path.exists(pptx_output_path):
        raise Exception("Visual agent did not create presentation.pptx")
    
    print(f"\nPresentation ready: {pptx_output_path}")
    return pptx_output_path


def cleanup(request_id: str):
    """Delete temp files after sending to Flutter"""
    import shutil
    folder = f"temp/{request_id}"
    if os.path.exists(folder):
        shutil.rmtree(folder)
        print(f"Cleaned up temp files for {request_id}")