# template_registry.py

TEMPLATES = {
    "ppt template 01": {
        "name":        "Chrome Tech",
        "file":        "templates/ppt template 01.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#000000",
        "font_color":"#FFFFFF",
        "preview":     "previews/Screenshot 2026-03-15 174427.png"
    },
    "ppt template 02": {
        "name":        "Sketch Deck",
        "file":        "templates/ppt template 02.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#FFFFFF",
        "font_color":"#000000",
        "preview":     "previews/Screenshot 2026-03-15 174440.png"
    },
    "ppt template 03": {
        "name":        "idk",
        "file":        "templates/ppt template 03.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#FFFFFF",
        "font_color":"#000000",
        "preview":     "previews/Screenshot 2026-03-15 174457.png"
    },
    "ppt template 04": {
        "name":        "Cyber Matrix",
        "file":        "templates/ppt template 04.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#FFFFFF",
        "font_color":"#000000",
        "preview":     "previews/Screenshot 2026-03-15 174508.png"
    },
    "ppt template 05": {
        "name":        "Neural Grid",
        "file":        "templates/ppt template 05.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#FFFFFF",
        "font_color":"#000000",
        "preview":     "previews/Screenshot 2026-03-15 174521.png"
    },
    "ppt template 06": {
        "name":        "Cloudlight",
        "file":        "templates/ppt template 06.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#000000",
        "font_color":"#FFFFFF",
        "preview":     "previews/Screenshot 2026-03-15 174535.png"
    },
    "ppt template 07": {
        "name":        "Natural Palette",
        "file":        "templates/ppt template 07.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#000000",
        "font_color":"#FFFFFF",
        "preview":     "previews/Screenshot 2026-03-15 174548.png"
    },
    "ppt template 08": {
        "name":        "Corporate Minimal",
        "file":        "templates/ppt template 08.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#000000",
        "font_color":"#FFFFFF",
        "preview":     "previews/Screenshot 2026-03-15 174557.png"
    }
}

def get_all_templates():
    return [
        {
            "id":          tid,
            "name":        t["name"],
            "description": t["description"],
            "preview":     t["preview"]
        }
        for tid, t in TEMPLATES.items()
    ]