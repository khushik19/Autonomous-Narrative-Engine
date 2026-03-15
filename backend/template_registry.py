# template_registry.py

TEMPLATES = {
    "Bold Text and Color Morph Product Launch Presentation": {
        "name":        "Bold Text and Color Morph Product Launch Presentation",
        "file":        "templates/Bold Text and Color Morph Product Launch Presentation.pptx",
        "description": "Clean corporate blue style",
        "accent_color":"#00A8E8",
        "preview":     "previews/Bold Text and Color Morph Product Launch Presentation.png"
    },
    "Cute Blackboard Student Council Presentation": {
        "name":        "Cute Blackboard Student Council Presentation", 
        "file":        "templates/Cute Blackboard Student Council Presentation.pptx",
        "description": "Sophisticated dark theme",
        "accent_color":"#E94560",
        "preview":     "previews/Cute Blackboard Student Council Presentation.png"
    },
    "Luxury Consulting Tool Presentation": {
        "name":        "Luxury Consulting Tool Presentation",
        "file":        "templates/Luxury Consulting Tool Presentation.pptx", 
        "description": "Clean minimal style",
        "accent_color":"#3498DB",
        "preview":     "previews/Luxury Consulting Tool Presentation.png"
    },
    "Mind Maps Boost by Slidesgo": {
        "name":        "Mind Maps Boost by Slidesgo",
        "file":        "templates/Mind Maps Boost by Slidesgo.pptx",
        "description": "Vibrant creative design",
        "accent_color":"#F39C12",
        "preview":     "previews/Mind Maps Boost by Slidesgo.png"
    },
    "Nature Journal": {
        "name":        "Nature Journal",
        "file":        "templates/Nature Journal.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
        "preview":     "previews/Nature Journal.png"
    },
    "ppt template 01": {
        "name":        "ppt template 01",
        "file":        "templates/ppt template 01.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
        "preview":     "previews/Screenshot 2026-03-15 174427.png"
    },
    "ppt template 02": {
        "name":        "ppt template 02",
        "file":        "templates/ppt template 02.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
        "preview":     "previews/Screenshot 2026-03-15 174440.png"
    },
    "ppt template 03": {
        "name":        "ppt template 03",
        "file":        "templates/ppt template 03.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
        "preview":     "previews/Screenshot 2026-03-15 174457.png"
    },
    "ppt template 04": {
        "name":        "ppt template 04",
        "file":        "templates/ppt template 04.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
        "preview":     "previews/Screenshot 2026-03-15 174508.png"
    },
    "ppt template 05": {
        "name":        "ppt template 05",
        "file":        "templates/ppt template 05.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
        "preview":     "previews/Screenshot 2026-03-15 174521.png"
    },
    "ppt template 06": {
        "name":        "ppt template 06",
        "file":        "templates/ppt template 06.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
        "preview":     "previews/Screenshot 2026-03-15 174535.png"
    },
    "ppt template 07": {
        "name":        "ppt template 07",
        "file":        "templates/ppt template 07.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
        "preview":     "previews/Screenshot 2026-03-15 174548.png"
    },
    "ppt template 08": {
        "name":        "ppt template 08",
        "file":        "templates/ppt template 08.pptx",
        "description": "Fresh eco-friendly style", 
        "accent_color":"#52B788",
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