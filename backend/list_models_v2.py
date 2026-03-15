
import google.generativeai as genai
import sys

# Ensure stdout is utf-8 just in case, though we write to file mainly
if sys.stdout.encoding != 'utf-8':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

API_KEY = "AIzaSyATpxUaFpC1y9ZflwFpPRiDEt3Xe2e2wYg"
genai.configure(api_key=API_KEY)

# Use a completely new filename
with open("available_models_final.txt", "w", encoding="utf-8") as f:
    f.write("Available models list:\n")
    try:
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                f.write(f"- {m.name}\n")
        f.write("\nEnd of list.\n")
    except Exception as e:
        f.write(f"Error listing models: {str(e)}\n")
print("Done writing available_models_final.txt")
