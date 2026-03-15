
import google.generativeai as genai

API_KEY = "AIzaSyATpxUaFpC1y9ZflwFpPRiDEt3Xe2e2wYg"
genai.configure(api_key=API_KEY)

with open("models_list.log", "w", encoding="utf-8") as f:
    f.write("Available models:\n")
    for m in genai.list_models():
        if 'generateContent' in m.supported_generation_methods:
            line = f"- {m.name}\n"
            print(line.strip())
            f.write(line)
