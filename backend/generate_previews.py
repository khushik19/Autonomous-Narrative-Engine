# generate_previews.py
# Run this ONE TIME to generate preview images
# python generate_previews.py

import os
import json

# ── Try using spire.presentation ──
try:
    from spire.presentation import Presentation as SpirePresentation
    from spire.presentation import FileFormat
    HAS_SPIRE = True
except:
    HAS_SPIRE = False
    print("Spire not available, using fallback")

from template_registry import TEMPLATES


def generate_preview_spire(pptx_path: str, output_path: str):
    """
    Uses Spire.Presentation to convert first slide to image
    Free version adds small watermark but works fine for preview
    """
    prs = SpirePresentation()
    prs.LoadFromFile(pptx_path)
    
    # Get first slide as image
    image = prs.Slides[0].SaveAsImage()
    image.Save(output_path)
    image.Dispose()
    prs.Dispose()
    print(f"  Preview saved: {output_path}")


def generate_preview_fallback(template_id: str, output_path: str):
    """
    Fallback: creates a colored placeholder image
    Uses the accent color of the template
    """
    from PIL import Image, ImageDraw, ImageFont
    
    template = TEMPLATES[template_id]
    
    # Get accent color
    accent = template.get("accent_color", "#0066CC")
    primary = template.get("primary_color", "#1E3A5F")
    
    def hex_to_rgb(h):
        h = h.lstrip("#")
        return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
    
    # Create 16:9 image
    width, height = 640, 360
    img = Image.new("RGB", (width, height), hex_to_rgb(primary))
    draw = ImageDraw.Draw(img)
    
    # Draw accent bar on left
    draw.rectangle([0, 0, 12, height], fill=hex_to_rgb(accent))
    
    # Draw template name
    name = template["name"]
    
    # Try to use a font, fallback to default
    try:
        font_big   = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 36)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
    except:
        font_big   = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # White text in center
    draw.text((width//2, height//2 - 30), name,
              fill=(255, 255, 255), font=font_big, anchor="mm")
    
    draw.text((width//2, height//2 + 20), template["description"],
              fill=(200, 200, 200), font=font_small, anchor="mm")
    
    # Accent line under title
    draw.rectangle(
        [width//2 - 60, height//2 + 5, width//2 + 60, height//2 + 8],
        fill=hex_to_rgb(accent)
    )
    
    # Slide icon dots at bottom
    for i in range(3):
        x = width//2 - 20 + (i * 20)
        draw.ellipse([x-5, height-30-5, x+5, height-30+5],
                    fill=hex_to_rgb(accent))
    
    img.save(output_path, "PNG")
    print(f"  Placeholder preview saved: {output_path}")


def generate_all_previews():
    """Generate preview for every template"""
    
    os.makedirs("previews", exist_ok=True)
    
    for template_id, template in TEMPLATES.items():
        pptx_path    = template["file"]
        output_path  = f"previews/{template_id}.png"
        
        print(f"Generating preview for: {template['name']}")
        
        # Skip if already exists
        if os.path.exists(output_path):
            print(f"  Already exists, skipping")
            continue
        
        if not os.path.exists(pptx_path):
            print(f"  PPTX not found: {pptx_path}")
            continue
        
        try:
            if HAS_SPIRE:
                generate_preview_spire(pptx_path, output_path)
            else:
                generate_preview_fallback(template_id, output_path)
        except Exception as e:
            print(f"  Error: {e}")
            # Always fallback to colored placeholder
            generate_preview_fallback(template_id, output_path)
    
    print("\nAll previews generated!")


if __name__ == "__main__":
    generate_all_previews()