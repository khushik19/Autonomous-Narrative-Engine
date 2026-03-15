# 🚀 Cosmos: AI-Powered Presentation Generator
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg) ![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?logo=flutter) ![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi) ![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)

**Cosmos** is an AI-powered system that automatically turns any topic or document into a professional PowerPoint (.pptx) presentation. It uses a Multi-Agent AI pipeline to handle research, writing, and design in one go.

## 💡 The Problem It Solves
Creating a good presentation takes a lot of time and effort. You have to research facts, write concise bullet points, and perfectly format the slides. Most AI tools can only write text, leaving you to do the formatting. Cosmos handles the entire process from start to finish with a single click, saving you hours of work.

---

## 🌟 Standout Features

### 1. Smart Fact-Checking (No Hallucinations)
Most AIs make things up. Cosmos solves this by using a "Two-Agent" system. One AI drafts the presentation, and a second "Critic" AI double-checks every single fact against the actual research. If a fact isn't real, it gets deleted and rewritten. 

### 2. Bring Your Own Data (File Uploads)
Don't want the AI searching the web? You can upload your own custom files. Cosmos will read your document and generate a presentation based *strictly* on your file, making it perfect for private company reports or school notes.

### 3. Play a Game While You Wait! 🎮
AI takes a little time to "think." Instead of making you stare at a boring loading screen, we built a **2D Asteroid Space Shooter** directly into the app!
* **Built from Scratch:** The game runs at a smooth 60fps using a custom Flutter game engine.
* **Real Physics:** It features hit detection, particle explosions, and smooth vector graphics. 
* **Live Updates:** While you shoot asteroids, real-time updates pop up on the screen so you know exactly what the AI is doing in the background.

### 4. You Are in Control
You can customize exactly how your presentation looks and feels:
**Detail Level:** Choose if you want short, punchy bullet points or highly detailed slides.
**Slide Count:** Tell the AI exactly how many slides you need.
**Custom Templates:** Choose from our built-in designs or upload your own .pptx template. Cosmos will smartly place text on your template without ruining your background images.

---

## 🧠 How the AI Works (The 3 Agents)

Cosmos acts like a 3-person team working together on the backend:
1. **The Researcher Agent:** Searches the web (or reads your uploaded file) to gather deep, factual information. It saves everything into a `research.txt` file.
2. **The Copywriter Agent:** Takes the heavy research and formats it into clean presentation slides (Titles, Subtitles, and Bullet Points). It saves this structured layout as a `content.json` file.
3. **The Visual Designer Agent:** Uses Python to open a PowerPoint file and perfectly place the text onto the slides, making sure nothing overlaps.

### 🛡️ Safe and Reliable
* **No Mixed Data:** Every time someone asks for a presentation, Cosmos creates a temporary, locked folder (`temp/<request_id>/`) just for them. This guarantees your data never mixes with someone else's.

---

## 💻 Tech Stack

* **Backend:** Python, FastAPI (for handling requests quickly).
* **AI Engine:** Google Gemini (Multi-Agent Pipeline).
* **Slide Generator:** `python-pptx`.
* **Frontend:** Flutter & Dart (works on Web, Android, iOS, and Desktop). 

---

## 🚀 Getting Started (Run Locally)

### 1. Backend Setup
Open your terminal, go to the backend folder, and set up your Python environment:
```bash
cd backend
python -m venv venv

# On Windows:
venv\Scripts\activate
# On Mac/Linux:
source venv/bin/activate

```

## Install the required packages:
```
pip install -r requirements.txt
uvicorn server:app --reload --port 8000
```


## Frontend Setup:
```
cd frontend
flutter pub get
flutter run
```
### Future Scope

Future improvements include:
1. **Interactive Editing:** Storing intermediate content.json securely to allow users to edit text blocks in the frontend before the Visual Designer Agent executes the final PowerPoint render.
2. **Advanced Visual Semantics:** Further integration into chart rendering using seaborn/matplotlib and dynamic icon fetching natively to the .pptx shapes.
3. **Personal templates:** Feature that lets a user import or upload an editable template from sites like canva, powerpoint etc 
