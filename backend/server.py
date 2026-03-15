# server.py
from fastapi import FastAPI, UploadFile, File, Form, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import shutil
import os
import json
import base64
import asyncio
from concurrent.futures import ThreadPoolExecutor

app = FastAPI()
_pipeline_executor = ThreadPoolExecutor(max_workers=2)

# Allow Flutter to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    """Start model loading in background thread — server starts instantly."""
    import threading
    def _bg_load():
        try:
            print("\n[Server] Loading models in background...")
            from agents.copywriter_agent import _load
            _load()
            print("[Server] Models loaded successfully.\n")
        except Exception as e:
            print(f"[Server] Model pre-loading failed (will retry on first request): {e}")
    
    thread = threading.Thread(target=_bg_load, daemon=True)
    thread.start()
    print("[Server] Started — model loading in background thread.")


# ── Health check ──
@app.get("/health")
async def health():
    return {"status": "running"}


# ── Get all templates ──
@app.get("/templates")
async def get_templates():
    from template_registry import get_all_templates
    return JSONResponse(get_all_templates())

# ── Serve preview images as static files ──  ← ADD THIS
os.makedirs("previews", exist_ok=True)
app.mount("/previews", StaticFiles(directory="previews"), name="previews")


# ── MAIN: Generate presentation ──
@app.post("/generate")
async def generate(
    topic:       str        = Form(...),
    template_id: str        = Form("modern_blue"),
    custom_file: UploadFile = File(None),
):
    print(f"New POST request — Topic: {topic}, Template: {template_id}")
    
    custom_path = None
    
    try:
        # Save uploaded template if user sent one
        if custom_file and custom_file.filename:
            os.makedirs("temp", exist_ok=True)
            custom_path = f"temp/uploaded_{custom_file.filename}"
            with open(custom_path, "wb") as f:
                shutil.copyfileobj(custom_file.file, f)
        
        # Run all 3 agents
        from pipeline import run_pipeline
        output_path = run_pipeline(
            topic                = topic,
            template_id          = template_id,
            custom_template_path = custom_path
        )
        
        # Send file to Flutter
        return FileResponse(
            path       = output_path,
            media_type = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            filename   = f"{topic[:20]}_presentation.pptx"
        )
    
    except Exception as e:
        print(f"Error: {e}")
        return JSONResponse(
            status_code = 500,
            content     = {"error": str(e)}
        )
    
    finally:
        # Clean up uploaded template
        if custom_path and os.path.exists(custom_path):
            os.remove(custom_path)


# ── MAIN: Generate presentation via WebSocket ──
@app.websocket("/ws/generate")
async def websocket_generate(websocket: WebSocket):
    await websocket.accept()
    print("New WebSocket connection accepted on /ws/generate")
    custom_path = None
    try:
        # 1. Receive JSON payload
        data_str = await websocket.receive_text()
        payload = json.loads(data_str)
        topic = payload.get("topic") or "Default Topic"
        template_id = payload.get("template_id") or "modern_blue"
        template_bytes_b64 = payload.get("template_bytes")
        
        print(f"WebSocket request — Topic: {topic}, Template: {template_id}")
        
        # Parse uploaded template bytes if they exist
        if template_bytes_b64:
            os.makedirs("temp", exist_ok=True)
            custom_path = f"temp/ws_uploaded_temp_{topic[:10].replace(' ', '_')}.pptx"
            with open(custom_path, "wb") as f:
                f.write(base64.b64decode(template_bytes_b64))
                
        # 2. Send status updates
        await websocket.send_json({"type": "status", "index": 0})
        await asyncio.sleep(0.5)
        
        await websocket.send_json({"type": "status", "index": 1})
        await asyncio.sleep(0.5)
        
        await websocket.send_json({"type": "status", "index": 2})
        
        # 3. Run Pipeline in a THREAD so we don't block the event loop
        from pipeline import run_pipeline
        loop = asyncio.get_event_loop()
        output_path = await loop.run_in_executor(
            _pipeline_executor,
            lambda: run_pipeline(
                topic=topic,
                template_id=template_id,
                custom_template_path=custom_path
            )
        )
        
        # 4. Synthesize Fact-checking / Generating Visuals
        await websocket.send_json({"type": "status", "index": 3})
        await asyncio.sleep(1)
        await websocket.send_json({"type": "status", "index": 4})
        
        # 5. Convert final output to Base64
        with open(output_path, "rb") as f:
            pptx_bytes = f.read()
        pptx_b64 = base64.b64encode(pptx_bytes).decode("utf-8")
        
        # 6. Send Done message with Base64 PPTX
        await websocket.send_json({
            "type": "done",
            "sources": [
                f"https://en.wikipedia.org/wiki/{topic.replace(' ', '_')}",
                f"https://www.google.com/search?q={topic.replace(' ', '+')}"
            ],
            "pdf_base64": "", # PDF not yet supported by pipeline
            "pptx_base64": pptx_b64
        })
        
    except WebSocketDisconnect:
        print("WebSocket client disconnected")
    except Exception as e:
        print(f"WebSocket Error: {e}")
        # Could send error message if required, but standard is just closing
    finally:
        # Clean up uploaded template
        if custom_path and os.path.exists(custom_path):
            os.remove(custom_path)
