# server.py
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import shutil
import os

app = FastAPI()

# Allow Flutter to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Health check ──
@app.get("/health")
async def health():
    return {"status": "running"}


# ── Get all templates ──
@app.get("/templates")
async def get_templates():
    from template_registry import get_all_templates
    return JSONResponse(get_all_templates())


# ── MAIN: Generate presentation ──
@app.post("/generate")
async def generate(
    topic:       str        = Form(...),
    template_id: str        = Form("modern_blue"),
    custom_file: UploadFile = File(None),
):
    print(f"New request — Topic: {topic}, Template: {template_id}")
    
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