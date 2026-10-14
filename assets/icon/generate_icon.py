#!/usr/bin/env python3
"""
Simple script to generate ChordBook app icons
"""
from PIL import Image, ImageDraw, ImageFont
import os

def create_icon(size, filename):
    """Create a simple icon with musical note and text"""
    # Create image with blue background
    img = Image.new('RGB', (size, size), color='#2196F3')
    draw = ImageDraw.Draw(img)
    
    # Draw a simple musical note shape
    # Note head (circle)
    note_size = size // 3
    center_x = size // 2
    center_y = size // 2 + size // 10
    
    # Draw note head (filled circle)
    draw.ellipse(
        [center_x - note_size//2, center_y - note_size//2, 
         center_x + note_size//2, center_y + note_size//2],
        fill='white'
    )
    
    # Draw note stem (vertical line)
    stem_width = size // 20
    stem_height = size // 2
    draw.rectangle(
        [center_x + note_size//2 - stem_width, center_y - stem_height,
         center_x + note_size//2, center_y],
        fill='white'
    )
    
    # Draw flag (curved line at top)
    flag_width = size // 6
    draw.ellipse(
        [center_x + note_size//2 - stem_width, center_y - stem_height - flag_width//2,
         center_x + note_size//2 + flag_width, center_y - stem_height + flag_width//2],
        fill='white'
    )
    
    # Save the image
    img.save(filename, 'PNG')
    print(f"Created {filename} ({size}x{size})")

def create_foreground_icon(size, filename):
    """Create foreground icon with transparency"""
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), color=(0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw a simple musical note shape (same as above but with transparency)
    note_size = size // 3
    center_x = size // 2
    center_y = size // 2 + size // 10
    
    # Draw note head (filled circle)
    draw.ellipse(
        [center_x - note_size//2, center_y - note_size//2, 
         center_x + note_size//2, center_y + note_size//2],
        fill='white'
    )
    
    # Draw note stem
    stem_width = size // 20
    stem_height = size // 2
    draw.rectangle(
        [center_x + note_size//2 - stem_width, center_y - stem_height,
         center_x + note_size//2, center_y],
        fill='white'
    )
    
    # Draw flag
    flag_width = size // 6
    draw.ellipse(
        [center_x + note_size//2 - stem_width, center_y - stem_height - flag_width//2,
         center_x + note_size//2 + flag_width, center_y - stem_height + flag_width//2],
        fill='white'
    )
    
    # Save the image
    img.save(filename, 'PNG')
    print(f"Created {filename} ({size}x{size})")

if __name__ == '__main__':
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Create main icon (1024x1024)
    create_icon(1024, os.path.join(script_dir, 'app_icon.png'))
    
    # Create adaptive icon foreground (1024x1024)
    create_foreground_icon(1024, os.path.join(script_dir, 'app_icon_foreground.png'))
    
    print("\nIcons created successfully!")
    print("Run: flutter pub get")
    print("Then: dart run flutter_launcher_icons")
