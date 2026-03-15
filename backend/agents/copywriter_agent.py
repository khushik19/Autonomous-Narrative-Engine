"""
PPT JSON Inference
------------------
Usage:
    from ppt_inference import run
    slides = run("your research text here")
    print(slides)
"""

import torch, json, re, os, zipfile, gc
from transformers import AutoModelForCausalLM, AutoTokenizer, GenerationConfig
from peft import PeftModel

# ── Config ────────────────────────────────────────────────────────────────────
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.dirname(_SCRIPT_DIR)
ZIP_PATH    = os.path.join(_BACKEND_DIR, "models", "ppt_json_merged_model.zip")
EXTRACT_DIR = os.path.join(_BACKEND_DIR, "models", "ppt_json_merged")
BASE_MODEL  = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"

_model     = None
_tokenizer = None


def _load():
    """Load model once, reuse on subsequent calls."""
    global _model, _tokenizer

    if _model is not None:
        return  # already loaded

    # ── Extract ZIP if model folder doesn't exist ─────────────────────────────
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

    # ── Check what's inside the extracted folder ──────────────────────────────
    # Merged model has config.json at root; adapter has adapter_config.json
    is_merged = os.path.isfile(os.path.join(EXTRACT_DIR, "config.json"))
    is_adapter = os.path.isfile(os.path.join(EXTRACT_DIR, "adapter_config.json"))

    print("Loading tokenizer ...")
    _tokenizer = AutoTokenizer.from_pretrained(EXTRACT_DIR)
    _tokenizer.pad_token = _tokenizer.eos_token

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype  = torch.float16  # Always use float16 to save memory (works fine on CPU too)
    print(f"Device: {device}  |  dtype: {dtype}")

    if is_merged:
        # Fully merged — load directly, no base model needed
        print("Loading merged model ...")
        _model = AutoModelForCausalLM.from_pretrained(
            EXTRACT_DIR,
            torch_dtype=dtype,
            device_map="auto" if device == "cuda" else None,
            low_cpu_mem_usage=True,
            trust_remote_code=True,
        )

    elif is_adapter:
        # LoRA adapter — need base model + apply adapter
        print(f"Loading base model ({BASE_MODEL}) + LoRA adapter ...")
        base = AutoModelForCausalLM.from_pretrained(
            BASE_MODEL,
            torch_dtype=dtype,
            device_map="auto" if device == "cuda" else None,
            low_cpu_mem_usage=True,
            trust_remote_code=True,
        )
        _model = PeftModel.from_pretrained(base, EXTRACT_DIR)

    else:
        raise RuntimeError(
            f"Could not identify model type in '{EXTRACT_DIR}'.\n"
            "Expected config.json (merged) or adapter_config.json (LoRA adapter)."
        )

    _model.eval()
    if torch.cuda.is_available():
        used = torch.cuda.memory_allocated() / 1e9
        print(f"Model ready!  VRAM used: {used:.2f} GB")
    else:
        print("Model ready! (running on CPU - will be slower)")


def run(input_path: str, output_path: str):
    """
    input_path:  path to research.txt file
    output_path: where to save content.json
    """
    print(f"\n[Copywriter Agent] Processing research from: {input_path}")
    
    # Read the research text
    with open(input_path, "r", encoding="utf-8") as f:
        research_data = json.load(f)
    
    research_text = research_data.get("verified_content", "")
    if not research_text:
        research_text = str(research_data)

    # Check if we already have slides from research agent
    existing_slides = research_data.get("slides", [])
    
    # Try to polish the output
    # If we have existing slides, we pass them as context to make it easier for the local model
    slides = run_inference(research_text, existing_slides=existing_slides)
    
    # FALLBACK: If inference failed but we have existing slides, use them!
    if not slides and existing_slides:
        print("[Copywriter Agent] Inference failed. Falling back to Research Agent's slides.")
        slides = existing_slides
    elif not slides:
        raise Exception("Copywriter agent failed to generate slides and no fallback available.")

    # At the end save content.json
    content = {
        "presentation_title": research_data.get("topic", "Presentation"),
        "theme": "modern",
        "slides": slides
    }
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(content, f, indent=2)
    
    print(f"Content saved to: {output_path}")
    return content

def run_inference(research_text: str, existing_slides: list = None, max_new_tokens: int = 512) -> list | None:
    """
    Internal function to convert research text into a list of slide dicts.
    Uses TinyLlama ChatML format.
    """
    _load()  # no-op if already loaded

    # 1. Manual Truncation to ensure prompt instructions fit.
    if len(research_text) > 4000:
        print(f"--- DEBUG: Truncating research text from {len(research_text)} to 4000 chars ---")
        research_text = research_text[:2000] + "\n... [TRUNCATED] ...\n" + research_text[-2000:]

    if existing_slides:
        # Easy Mode: Polishing existing slides
        prompt_content = f"Polishing these existing slides for better flow and detail:\n{json.dumps(existing_slides, indent=2)}"
        target_token_count = 1000
    else:
        # Hard Mode: Generating slides from scratch
        prompt_content = f"Research Input:\n{research_text}"
        target_token_count = 1536

    prompt = (
        "<|user|>\n"
        "Convert the following research data into a structured JSON array of slides.\n"
        "Each slide must have: slide_number, title, slide_type, and at least one of: subtitle, bullets, or data.\n"
        "Sufficiently detailed explanations and multiple bullet points are encouraged. Be thorough.\n"
        "Slide types: 'intro', 'hero', 'bullet_points', 'chart', 'stat', 'quote', 'closing'.\n"
        "If a slide would benefit from data visualization (stats, trends, growth), use slide_type: 'chart' and include a 'data' field:\n"
        "- data: { \"type\": \"bar_chart\"|\"line_chart\"|\"pie_chart\", \"labels\": [...], \"values\": [numbers only, no quotes], \"xlabel\": \"...\", \"ylabel\": \"...\" }\n\n"
        f"{prompt_content}</s>\n"
        "<|assistant|>\n[" # Force start of JSON array
    )

    _tokenizer.truncation_side = 'left'
    inputs = _tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        max_length=target_token_count,
    )

    device = next(_model.parameters()).device
    inputs = {k: v.to(device) for k, v in inputs.items()}

    # Clear model default max_length so we don't get "both max_length and max_new_tokens" warning
    if getattr(_model, "generation_config", None) is not None:
        _model.generation_config.max_length = None  # clear model default

    gen_cfg = GenerationConfig(
        max_new_tokens=max_new_tokens,
        max_length=None,
        do_sample=False,
        pad_token_id=_tokenizer.eos_token_id,
    )
    with torch.no_grad():
        out = _model.generate(**inputs, generation_config=gen_cfg)
    
    # We forced the '[' in the prompt, so prepend it to the decoded output
    new_tokens = out[0][inputs["input_ids"].shape[1]:]
    raw = "[" + _tokenizer.decode(new_tokens, skip_special_tokens=True).strip()

    print(f"=== DEBUG: RAW OUTPUT LENGTH: {len(raw)} ===")
    print(f"=== DEBUG: RAW OUTPUT START: {repr(raw[:100])} ===")
    print(f"=== MODEL RAW OUTPUT ===\n{repr(raw)}\n=== END MODEL RAW OUTPUT ===")

    if not raw:
        print("Warning: model produced no output (empty string).")
        return None

    try:
        # Clean up common LLM issues before parsing
        raw = raw.strip()
        
        # 1. Try to find JSON array using brackets
        start = raw.find('[')
        end = raw.rfind(']') + 1
        if start != -1 and end > start:
            json_str = raw[start:end]
            # Try to fix truncated JSON if it ends abruptly but near the end
            if "]" not in json_str[-5:]:
                # If it looks like it was cut off (e.g. ends with , or inside an object)
                # This is a bit risky but can save some outputs
                try:
                    # Try to close brackets
                    test_str = json_str.rstrip()
                    if test_str.endswith(','): test_str = test_str[:-1]
                    # Append enough closers (heuristic)
                    for _ in range(5):
                        test_str += "}"
                        try:
                            slides = json.loads(test_str + "]")
                            print("=== DEBUG: Successfully parsed with manual bracket closing ===")
                            return slides
                        except: continue
                except: pass

            print(f"=== DEBUG: Found JSON-like string of length {len(json_str)} ===")
            slides = json.loads(json_str)
            return slides
        
        # 2. Try to parse the whole string as a last resort
        print("=== DEBUG: No brackets found, trying to parse entire string... ===")
        slides = json.loads(raw)
        return slides
    except (json.JSONDecodeError, AttributeError, ValueError) as e:
        print(f"Warning: could not parse JSON from model output: {e}")
        # 3. Last ditch: try to see if it's a python list representation if LLM got confused
        try:
            import ast
            # Basic cleanup for literal_eval
            clean_raw = raw.strip()
            if not clean_raw.startswith('['): clean_raw = '[' + clean_raw
            if not clean_raw.endswith(']'): clean_raw = clean_raw + ']'
            slides = ast.literal_eval(clean_raw)
            if isinstance(slides, list):
                print("=== DEBUG: Successfully parsed using ast.literal_eval ===")
                return slides
        except:
            pass
        return None


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
    slides = run(TEST, max_new_tokens=1024)

    if slides:
        ok, msg = validate(slides)
        print(f"\nValidation: {msg}")
        print(f"Generated {len(slides)} slides:\n")
        for s in slides:
            print(json.dumps(s, indent=2))
