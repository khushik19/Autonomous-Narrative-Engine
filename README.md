# 🚀 Narrativa: Autonomous Presentation Engine
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg) ![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?logo=flutter) ![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi) ![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)

[cite_start]Narrativa is a fully functional, automated presentation generation system designed to convert user-provided topics into high-quality PowerPoint (.pptx) slide decks[cite: 3]. [cite_start]Built for the **IIT Indore Ingenium Hackathon**, it leverages an advanced Multi-Agent pipeline to research, write, and visually design entire presentations autonomously[cite: 4, 6].

## 📑 Table of Contents
- [The Problem It Solves](#-the-problem-it-solves)
- [Key Features & Innovations](#-key-features--innovations)
- [System Architecture](#-system-architecture)
- [Tech Stack](#-tech-stack)
- [API Reference](#-api-reference)
- [Getting Started (Local Setup)](#-getting-started)
- [Project Structure](#-project-structure)
- [Future Enhancements](#-future-enhancements)
- [License](#-license)

---

## 💡 The Problem It Solves
Creating professional presentations is a time-consuming process that requires three distinct skill sets: research, copywriting, and visual design. Modern Generative AI systems excel at isolated tasks but fail to produce coherent, end-to-end narratives. [cite_start]Narrativa solves this by reducing the entire process into a single backend API call, turning raw data into compelling, structured narratives without requiring human-in-the-loop formatting[cite: 4].

---

## ✨ Key Features & Innovations

### 🛡️ Enterprise-Grade Backend Reliability
* [cite_start]**Isolated Workspaces:** Every generation request is assigned a unique ID via `uuid4()`, creating isolated temporary workspaces (`temp/<request_id>/`) to ensure zero cross-contamination between concurrent users[cite: 13, 37, 38].
* [cite_start]**Asynchronous Pipeline:** Prevents blocking of the main event thread, enabling high scalability[cite: 39].
* [cite_start]**Zero-Latency Start:** The backend utilizes a startup event background thread (`_bg_load()`) to initialize heavy LLM pipelines efficiently, preventing severe latency on the first request[cite: 40].

### 🎮 Gamified Loading Experience (Built from Scratch)
To combat natural LLM processing times, we built a 2D space shooter directly into the loading screen!
* **Custom Game Engine:** Built using a `Timer.periodic` 60fps (16ms) game loop natively in Flutter.
* **Vector Rendering:** Ships, asteroids, and stars are drawn mathematically on a `CustomPaint` canvas.
* **Physics & Mechanics:** Features custom collision detection (bullet-asteroid and ship-asteroid) and a built-in particle system for asteroid destruction burst effects.
* **Responsive Layout:** Uses `LayoutBuilder` for responsive canvas sizing and `Stack` + `Positioned` for overlay layering.

### ⚡ Real-Time Streaming
* [cite_start]Implements `dart:html WebSocket` to stream real-time status updates from the backend pipeline down to the Flutter frontend UI during generation[cite: 42].

---

## 🏗️ System Architecture

[cite_start]The architecture follows a Client-Server model extended by an intelligent Multi-Agent computational pipeline[cite: 6]. 

### The Three-Agent Pipeline
[cite_start]The core functionality resides in `pipeline.py`, running serially through three specialized agents[cite: 13, 14, 15]:
1. [cite_start]**Research Agent (`research_agent.py`):** Gathers and synthesizes broad information[cite: 16, 17]. [cite_start]It leverages LLMs to formulate a structured thought process, covering history, current context, quantitative metrics, and future outlooks[cite: 18, 19]. [cite_start]Outputs raw data to `research.txt`[cite: 20].
2. [cite_start]**Copywriter Agent (`copywriter_agent.py`):** Transforms the unstructured text into presentation-ready snippets[cite: 21, 22]. [cite_start]It applies strict prompt constraints to specify maximum text lengths, ensuring titles, subtitles, and bullet points fit standard PowerPoint layouts[cite: 24, 25]. [cite_start]Outputs mapped data to `content.json`[cite: 26].
3. [cite_start]**Visual Designer Agent (`visual_agent.py`):** Binds the structured JSON payloads onto functional PowerPoint elements[cite: 27, 28]. [cite_start]Utilizing `python-pptx`, it programmatically opens the template, intelligently resizes text shapes, and preserves existing graphic backgrounds[cite: 29, 30]. [cite_start]Outputs the final `presentation.pptx`[cite: 31].

---

## 💻 Tech Stack

**Backend:**
* Python & FastAPI (CORS-enabled orchestrator) [cite: 8, 9]
* [cite_start]`python-pptx` (Visual Designer Engine) [cite: 29]
* [cite_start]Multi-Agent LLMs (Google Gemini) [cite: 18]

**Frontend (Flutter/Dart):**
* Cross-platform UI compilation (Web, Android, iOS, Desktop) [cite: 33, 64]
* **State Management:** Native Flutter `setState` (no external bloatware library used).
* **Animations:** `SingleTickerProviderStateMixin`, `AnimationController`, and `Tween` for smooth UI transitions and scroll arrow bouncing.
* **Navigation:** `ScrollController` with `animateTo` for smooth scrolling, and `Navigator.push` for full-screen page transitions.

---

## 🔌 API Reference

[cite_start]The FastAPI backend exposes the following primary endpoints[cite: 8, 58]:

* **`POST /generate`**
  [cite_start]Takes in form data containing a presentation topic, alongside either a `template_id` or a custom `UploadFile`[cite: 10]. [cite_start]Triggers the Multi-Agent pipeline (`pipeline.py`)[cite: 11].
* **`GET /templates`**
  Fetches built-in `.pptx` template metadata, including layout paths and visual previews (`template_registry.py`)[cite: 11].

---

## 🚀 Getting Started

### Prerequisites
* Python 3.10+
* Flutter SDK (Latest stable release)

### 1. Backend Setup
Navigate to the backend directory and set up the virtual environment:
```bash
cd backend
python -m venv venv
