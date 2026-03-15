#Imports & API Setup
import json
import os
import requests
import time
import google.generativeai as genai
from duckduckgo_search import DDGS

#API
GEMINI_API_KEY = "AIzaSyD6zJVYoDKJSzG08WcguNdGPL0UZK59jW8"
genai.configure(api_key=GEMINI_API_KEY)

# Using gemini-1.5-flash for higher quota limits
model = genai.GenerativeModel('models/gemini-3-flash-preview')

def extract_text_from_pdf(pdf_path: str) -> str:
    """Extracts text from a PDF file using pypdf."""
    try:
        from pypdf import PdfReader
        reader = PdfReader(pdf_path)
        extracted_text = ""
        for page in reader.pages:
            content = page.extract_text()
            if content:
                extracted_text += str(content) + "\n"
        return extracted_text
    except Exception as e:
        print(f"!! [Research Agent] PDF extraction failed: {e}")
        return ""

# The Researcher Engine
class ResearcherAgent:
    def __init__(self, model):
        self.model = model
        self.ddgs = DDGS()

    def _call_with_retry(self, prompt, max_retries=3):
        """Helper to handle 429 errors with exponential backoff."""
        for attempt in range(max_retries):
            try:
                return self.model.generate_content(prompt)
            except Exception as e:
                if "429" in str(e) and attempt < max_retries - 1:
                    wait_time = (2 ** attempt) * 5
                    print(f"!! [Quota] 429 hit. Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    raise e

    def plan_queries(self, topic):
        print(f"[Agent] Inferring search queries for: '{topic}'...")
        prompt = f"""
        You are a research assistant. The user wants to create a presentation on: "{topic}".
        Generate exactly 3 specific, distinct search queries to find the most up-to-date factual information on this.
        Return ONLY a raw JSON list of strings. No markdown formatting, no backticks.
        Example: ["query 1", "query 2", "query 3"]
        """
        response = self._call_with_retry(prompt)
        try:
            return json.loads(response.text.strip())
        except json.JSONDecodeError:
            # Fallback for common formatting issues
            text = response.text.strip()
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0].strip()
            elif "```" in text:
                text = text.split("```")[1].split("```")[0].strip()
            try:
                return json.loads(text)
            except:
                return [f"{topic} latest news", f"{topic} statistics", f"{topic} analysis"]

    def search_and_scrape(self, queries):
        print("[Pipeline] Searching the web and scraping live data...")
        all_urls = []
        for q in queries:
            try:
                results = self.ddgs.text(q, max_results=2)
                for r in results:
                    all_urls.append(r['href'])
            except Exception as e:
                print(f"   -> Search error for query '{q}': {e}")

        unique_urls = list(set(all_urls))
        scraped_knowledge = ""
        successful_sources = []

        for url in unique_urls:
            print(f"   -> Scraping: {url}")
            jina_url = f"https://r.jina.ai/{url}"
            try:
                resp = requests.get(jina_url, timeout=10)
                if resp.status_code == 200:
                    text = resp.text[:3000]
                    scraped_knowledge += f"\n\n--- Source: {url} ---\n{text}"
                    successful_sources.append(url)
            except Exception as e:
                print(f"   -> Failed to scrape {url}")

        return scraped_knowledge, successful_sources

    def synthesize_and_verify(self, topic, knowledge, style, num_slides):
        """Consolidated drafting and self-verification in one call to output JSON slides."""
        print("[Agent] Synthesizing and self-verifying JSON slides...")

        if style == "concise":
            style_instruction = "Focus on short, punchy bullet points and hard statistics."
        else:
            style_instruction = "Provide detailed paragraphs, deep insights, and comprehensive context."

        prompt = f"""
        You are an expert presentation copywriter and fact-checker.
        Topic: "{topic}"
        Total Slides: {num_slides}
        Style: {style_instruction}

        ### SCRAPED KNOWLEDGE:
        {knowledge}

        ### INSTRUCTIONS:
        1. Read the SCRAPED KNOWLEDGE carefully.
        2. Plan a structured {num_slides}-slide presentation.
        3. For each slide, determine a title and content (bullets or text).
        4. CRITICAL: Use ONLY information from the SCRAPED KNOWLEDGE.
        5. OUTPUT: Return a raw JSON array of slides. 
        Each slide must have: "slide_number", "title", "slide_type", and at least one of ["subtitle", "bullets", "data"].
        Slide types: 'intro', 'hero', 'bullet_points', 'chart', 'stat', 'quote', 'closing'.
        If a slide would benefit from data visualization (stats, trends, growth), use slide_type: 'chart' and include a 'data' field:
        - data: {{ "type": "bar_chart" or "line_chart" or "pie_chart", "labels": [...], "values": [...], "xlabel": "...", "ylabel": "..." }}
        Example Slide: {{"slide_number": 1, "title": "...", "slide_type": "bullet_points", "bullets": ["First detailed point", "Second detailed point with more context"]}}
        Return ONLY the raw JSON array. No markdown, no backticks.
        """
        response = self._call_with_retry(prompt)
        text = response.text.strip()
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        elif "```" in text:
            text = text.split("```")[1].split("```")[0].strip()
        
        try:
            return json.loads(text)
        except:
            print("!! Failed to parse JSON synthesis. Returning as list of slides text.")
            return [{"slide_number": 1, "title": "Research Summary", "subtitle": text}]

def run(topic: str, output_path: str, deck_style: str = "detailed", num_slides: int = 7, pdf_path: str = None):
    print(f"\n[Research Agent] Starting research for topic: '{topic}'")
    researcher = ResearcherAgent(model)
    
    # Step 1: Query Planning
    queries = researcher.plan_queries(topic)
    
    # Step 2: Search and Scrape
    knowledge_base, sources = researcher.search_and_scrape(queries)
    
    # Step 3: Extract text from PDF if available
    pdf_text = ""
    if pdf_path and os.path.exists(pdf_path):
        print(f"[Research Agent] Extracting text from PDF: {pdf_path}")
        pdf_text = extract_text_from_pdf(pdf_path)
        if pdf_text:
            knowledge_base = f"--- [UPLOADED PDF CONTENT] ---\n{pdf_text}\n\n--- [WEB SEARCH KNOWLEDGE] ---\n" + knowledge_base
            sources.append("Uploaded PDF Document")

    if not knowledge_base:
        print("!! No knowledge base found. Using default topic info.")
        knowledge_base = f"Research data for {topic} was unavailable at scraping time."

    # Step 3: Consolidated Synthesize & Verify (Produces JSON)
    slides = researcher.synthesize_and_verify(topic, knowledge_base, deck_style, num_slides)

    final_payload = {
        "topic": topic,
        "sources_used": sources,
        "verified_content": knowledge_base, # Keep raw knowledge for backup
        "slides": slides
    }

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(final_payload, f, indent=2)
    
    print(f"Research saved to: {output_path}")
    return final_payload


# Interactive Setup (only if run directly)
if __name__ == "__main__":
    print("=== 🎯 PRESENTATION SETUP ===")
    topic_input = input("1. Enter the presentation topic: ")
    while True:
        style_input = input("2. Do you want a 'concise' or 'detailed' deck? ").strip().lower()
        if style_input in ['concise', 'detailed']:
            break
        print("   -> Invalid choice. Please type either 'concise' or 'detailed'.")
    while True:
        try:
            slides_input = int(input("3. How many slides do you need? (Minimum 5): "))
            if slides_input >= 5:
                break
            else:
                print("   -> Wait! The hackathon rules require a minimum of 5 slides.")
        except ValueError:
            print("   -> Please enter a valid number.")

    output_test_path = "temp/test_research/research.txt"
    run(topic=topic_input, output_path=output_test_path, deck_style=style_input, num_slides=slides_input)