"""
Copywriter Agent — Slide Content Polisher
------------------------------------------
Uses Gemini API (primary) to polish/generate slide JSON.
Falls back to local TinyLlama model if API fails.
Falls back to Research Agent's raw slides as last resort.
"""

import json, os, time
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# ── Gemini API Setup ──────────────────────────────────────────────────────────
_gemini_model = None

def _load_gemini():
    """Initialize Gemini API model (lazy, one-time)."""
    global _gemini_model
    if _gemini_model is not None:
        return _gemini_model

    try:
        import google.generativeai as genai
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            print("[Copywriter] No GEMINI_API_KEY found, Gemini unavailable.")
            return None
        genai.configure(api_key=api_key)
        _gemini_model = genai.GenerativeModel('models/gemini-2.5-flash-lite')
        print("[Copywriter] Gemini API ready.")
        return _gemini_model
    except Exception as e:
        print(f"[Copywriter] Gemini init failed: {e}")
        return None


# ── Local Model Setup (TinyLlama fallback) ────────────────────────────────────
_SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.dirname(_SCRIPT_DIR)
ZIP_PATH     = os.path.join(_BACKEND_DIR, "models", "ppt_json_merged_model.zip")
EXTRACT_DIR  = os.path.join(_BACKEND_DIR, "models", "ppt_json_merged")
BASE_MODEL   = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"

_local_model     = None
_local_tokenizer = None


def _load_local():
    """Load TinyLlama model once, reuse on subsequent calls."""
    global _local_model, _local_tokenizer

    if _local_model is not None:
        return  # already loaded

    import torch, zipfile
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from peft import PeftModel

    if not os.path.isdir(EXTRACT_DIR):
        if not os.path.isfile(ZIP_PATH):
            raise FileNotFoundError(
                f"Model ZIP not found: '{ZIP_PATH}'\n"
                f"Place the ZIP in backend/models/ or run from the project root."
            )
        print(f"Extracting {ZIP_PATH} ...")
        extract_to = os.path.dirname(EXTRACT_DIR)
        with zipfile.ZipFile(ZIP_PATH, "r") as z:
            z.extractall(extract_to)
        print("Extraction done.")

    is_merged  = os.path.isfile(os.path.join(EXTRACT_DIR, "config.json"))
    is_adapter = os.path.isfile(os.path.join(EXTRACT_DIR, "adapter_config.json"))

    print("Loading tokenizer ...")
    _local_tokenizer = AutoTokenizer.from_pretrained(EXTRACT_DIR)
    _local_tokenizer.pad_token = _local_tokenizer.eos_token

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype  = torch.float16
    print(f"Device: {device}  |  dtype: {dtype}")

    if is_merged:
        print("Loading merged model ...")
        _local_model = AutoModelForCausalLM.from_pretrained(
            EXTRACT_DIR,
            torch_dtype=dtype,
            device_map="auto" if device == "cuda" else None,
            low_cpu_mem_usage=True,
            trust_remote_code=True,
        )
    elif is_adapter:
        print(f"Loading base model ({BASE_MODEL}) + LoRA adapter ...")
        base = AutoModelForCausalLM.from_pretrained(
            BASE_MODEL,
            torch_dtype=dtype,
            device_map="auto" if device == "cuda" else None,
            low_cpu_mem_usage=True,
            trust_remote_code=True,
        )
        _local_model = PeftModel.from_pretrained(base, EXTRACT_DIR)
    else:
        raise RuntimeError(
            f"Could not identify model type in '{EXTRACT_DIR}'.\n"
            "Expected config.json (merged) or adapter_config.json (LoRA adapter)."
        )

    _local_model.eval()
    if torch.cuda.is_available():
        used = torch.cuda.memory_allocated() / 1e9
        print(f"Model ready!  VRAM used: {used:.2f} GB")
    else:
        print("Model ready! (running on CPU - will be slower)")


# ══════════════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

def run(input_path: str, output_path: str):
    """
    input_path:  path to research.txt (JSON) file
    output_path: where to save content.json
    """
    print(f"\n[Copywriter Agent] Processing research from: {input_path}")

    with open(input_path, "r", encoding="utf-8") as f:
        research_data = json.load(f)

    research_text   = research_data.get("verified_content", "")
    if not research_text:
        research_text = str(research_data)

    existing_slides = research_data.get("slides", [])
    topic           = research_data.get("topic", "Presentation")

    # ── Try Gemini API first (fast, reliable) ─────────────────────────────────
    slides = _run_gemini(topic, research_text, existing_slides)

    # ── Fallback to local TinyLlama ───────────────────────────────────────────
    if not slides:
        print("[Copywriter] Gemini failed — trying local model...")
        slides = _run_local(research_text, existing_slides)

    # ── Last resort: use Research Agent's raw slides ──────────────────────────
    if not slides and existing_slides:
        print("[Copywriter] All inference failed. Using Research Agent's slides.")
        slides = existing_slides
    elif not slides:
        raise Exception("Copywriter agent failed to generate slides and no fallback available.")

    content = {
        "presentation_title": topic,
        "theme": "modern",
        "slides": slides,
    }

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(content, f, indent=2)

    print(f"Content saved to: {output_path}")
    return content


# ══════════════════════════════════════════════════════════════════════════════
#  GEMINI INFERENCE (primary)
# ══════════════════════════════════════════════════════════════════════════════

def _call_gemini_with_retry(model, prompt, max_retries=3):
    """Handle 429 rate-limit errors with exponential backoff."""
    for attempt in range(max_retries):
        try:
            return model.generate_content(prompt)
        except Exception as e:
            if "429" in str(e) and attempt < max_retries - 1:
                wait_time = (2 ** attempt) * 5
                print(f"[Copywriter] 429 hit. Retrying in {wait_time}s...")
                time.sleep(wait_time)
            else:
                raise e


def _run_gemini(topic: str, research_text: str, existing_slides: list) -> list | None:
    """Polish or generate slides using Gemini API."""
    model = _load_gemini()
    if model is None:
        return None

    try:
        if existing_slides:
            slides_json = json.dumps(existing_slides, indent=2)
            prompt = f"""You are an expert presentation copywriter.
Topic: "{topic}"

You have these draft slides from a research agent:
{slides_json}

Polish them for a professional presentation:
1. Improve titles to be more engaging and specific.
2. Make bullet points more detailed, concrete, and insightful.
3. Keep the same slide_types and structure.
4. Ensure each slide has: "slide_number", "title", "slide_type", and at least one of ["subtitle", "bullets", "data"].
5. Valid slide_types: 'intro', 'hero', 'bullet_points', 'chart', 'stat', 'quote', 'closing'.
6. If a slide has a 'data' field for charts, keep it and improve labels if needed.

Return ONLY a raw JSON array of slide objects. No markdown, no backticks, no explanation."""
        else:
            # Truncate research if too long
            if len(research_text) > 8000:
                research_text = research_text[:4000] + "\n...[TRUNCATED]...\n" + research_text[-4000:]

            prompt = f"""You are an expert presentation copywriter.
Topic: "{topic}"

Research Data:
{research_text}

Create a structured JSON array of 7-8 slides for a professional presentation:
1. Each slide must have: "slide_number", "title", "slide_type", and at least one of ["subtitle", "bullets", "data"].
2. Valid slide_types: 'intro', 'hero', 'bullet_points', 'chart', 'stat', 'quote', 'closing'.
3. Use detailed, insightful bullet points with concrete facts.
4. For data visualization slides, include: data: {{ "type": "bar_chart"|"line_chart"|"pie_chart", "labels": [...], "values": [numbers], "xlabel": "...", "ylabel": "..." }}

Return ONLY a raw JSON array. No markdown, no backticks."""

        print("[Copywriter] Calling Gemini API...")
        response = _call_gemini_with_retry(model, prompt)
        text = response.text.strip()

        # Strip markdown fencing if present
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        elif "```" in text:
            text = text.split("```")[1].split("```")[0].strip()

        slides = json.loads(text)
        if isinstance(slides, list) and len(slides) > 0:
            print(f"[Copywriter] Gemini produced {len(slides)} polished slides.")
            return slides
        return None

    except Exception as e:
        print(f"[Copywriter] Gemini inference error: {e}")
        return None


# ══════════════════════════════════════════════════════════════════════════════
#  LOCAL MODEL INFERENCE (fallback)
# ══════════════════════════════════════════════════════════════════════════════

def _run_local(research_text: str, existing_slides: list = None, max_new_tokens: int = 512) -> list | None:
    """Convert research text into slide dicts using local TinyLlama model."""
    try:
        _load_local()
    except Exception as e:
        print(f"[Copywriter] Local model load failed: {e}")
        return None

    import torch
    from transformers import GenerationConfig

    if len(research_text) > 4000:
        research_text = research_text[:2000] + "\n... [TRUNCATED] ...\n" + research_text[-2000:]

    if existing_slides:
        prompt_content = f"Polishing these existing slides for better flow and detail:\n{json.dumps(existing_slides, indent=2)}"
        target_token_count = 1000
    else:
        prompt_content = f"Research Input:\n{research_text}"
        target_token_count = 1536

    user_tag = "<" + "|user|" + ">"
    end_tag = "<" + "/s" + ">"
    asst_tag = "<" + "|assistant|" + ">"

    prompt = (
        f"{user_tag}\n"
        "Convert the following research data into a structured JSON array of slides.\n"
        "Each slide must have: slide_number, title, slide_type, and at least one of: subtitle, bullets, or data.\n"
        "Slide types: 'intro', 'hero', 'bullet_points', 'chart', 'stat', 'quote', 'closing'.\n\n"
        f"{prompt_content}{end_tag}\n"
        f"{asst_tag}\n["
    )

    _local_tokenizer.truncation_side = 'left'
    inputs = _local_tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        max_length=target_token_count,
    )

    device = next(_local_model.parameters()).device
    inputs = {k: v.to(device) for k, v in inputs.items()}

    if getattr(_local_model, "generation_config", None) is not None:
        _local_model.generation_config.max_length = None

    gen_cfg = GenerationConfig(
        max_new_tokens=max_new_tokens,
        max_length=None,
        do_sample=False,
        pad_token_id=_local_tokenizer.eos_token_id,
    )
    with torch.no_grad():
        out = _local_model.generate(**inputs, generation_config=gen_cfg)

    new_tokens = out[0][inputs["input_ids"].shape[1]:]
    raw = "[" + _local_tokenizer.decode(new_tokens, skip_special_tokens=True).strip()

    print(f"[Copywriter Local] Raw output length: {len(raw)}")

    if not raw or len(raw) <= 2:
        return None

    try:
        raw = raw.strip()
        start = raw.find('[')
        end = raw.rfind(']') + 1
        if start != -1 and end > start:
            json_str = raw[start:end]
            slides = json.loads(json_str)
            print(f"[Copywriter Local] Parsed {len(slides)} slides.")
            return slides

        slides = json.loads(raw)
        return slides
    except (json.JSONDecodeError, ValueError) as e:
        print(f"[Copywriter Local] JSON parse failed: {e}")
        return None


# ── Schema Validation ─────────────────────────────────────────────────────────

def validate(slides: list) -> tuple[bool, str | list]:
    """Check that slides match the required schema."""
    if not isinstance(slides, list):
        return False, "Output must be a list"
    errors = []
    for i, s in enumerate(slides):
        if "slide_number" not in s: errors.append(f"Slide {i+1}: missing slide_number")
        if "title"        not in s: errors.append(f"Slide {i+1}: missing title")
        if "slide_type"   not in s: errors.append(f"Slide {i+1}: missing slide_type")
        if not any(k in s for k in ["subtitle", "bullets", "data"]):
            errors.append(f"Slide {i+1}: needs subtitle, bullets, or data")
    return (False, errors) if errors else (True, "All slides valid!")


# ── Quick test when run directly ──────────────────────────────────────────────
if __name__ == "__main__":
    TEST = """Topic: Global EV Market 2025
Slide 1: Overview. EV sales hit 18M units in 2024, up 35%. EVs are 20% of new car sales.
Slide 2: Battery Tech. Range increased to 420km. Cost fell to $95/kWh, down 90% since 2010.
Slide 3: Challenges. EVs still $8000 pricier than ICE. Only 40% of batteries recycled."""

    print("Running inference...")
    result = run("temp/test_research/research.txt", "temp/test_output/content.json")
    if result:
        ok, msg = validate(result["slides"])
        print(f"\nValidation: {msg}")
        print(f"Generated {len(result['slides'])} slides")
