#!/usr/bin/env python3
"""
Generate iOS app icon set from the green SelfTalk icon
"""

from PIL import Image, ImageDraw
import os

# iOS icon sizes needed for the app
icon_sizes = [
    (20, 1, "ipad"),     # iPad 20x20@1x
    (20, 2, "ipad"),     # iPad 20x20@2x
    (20, 2, "iphone"),   # iPhone 20x20@2x
    (20, 3, "iphone"),   # iPhone 20x20@3x
    (29, 1, "ipad"),     # iPad 29x29@1x
    (29, 2, "ipad"),     # iPad 29x29@2x
    (29, 2, "iphone"),   # iPhone 29x29@2x
    (29, 3, "iphone"),   # iPhone 29x29@3x
    (40, 1, "ipad"),     # iPad 40x40@1x
    (40, 2, "ipad"),     # iPad 40x40@2x
    (40, 2, "iphone"),   # iPhone 40x40@2x
    (40, 3, "iphone"),   # iPhone 40x40@3x
    (60, 2, "iphone"),   # iPhone 60x60@2x
    (60, 3, "iphone"),   # iPhone 60x60@3x
    (76, 1, "ipad"),     # iPad 76x76@1x
    (76, 2, "ipad"),     # iPad 76x76@2x
    (83.5, 2, "ipad"),   # iPad 83.5x83.5@2x
    (1024, 1, "ios-marketing"),  # App Store 1024x1024
]

def add_rounded_corners(img, radius_percent=22.5):
    """Add iOS-style rounded corners to an image"""
    width, height = img.size
    radius = int(min(width, height) * radius_percent / 100)

    # Create a mask for rounded corners
    mask = Image.new('L', (width, height), 0)
    draw = ImageDraw.Draw(mask)

    # Draw rounded rectangle
    draw.rounded_rectangle([(0, 0), (width-1, height-1)], radius=radius, fill=255)

    # Convert to RGBA and apply mask
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    output = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    output.paste(img, (0, 0))
    output.putalpha(mask)

    return output

def generate_icon_set():
    """Generate all required iOS icon sizes from the green icon"""

    # Paths
    source_path = "/Users/joker/github/xiaolai/myprojects/pando/pando-iOS/SelfTalk_iOS_IconPack/market-1024-ios.png"
    output_dir = "/Users/joker/github/xiaolai/myprojects/pando/pando-iOS/Pando Echo/Assets.xcassets/AppIcon.appiconset"

    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Load the source icon
    print(f"Loading source icon from: {source_path}")
    source_img = Image.open(source_path)

    # Ensure it's in RGBA mode
    if source_img.mode != 'RGBA':
        source_img = source_img.convert('RGBA')

    print(f"Source icon size: {source_img.size}")
    print("\nGenerating iOS icon set...")

    for base_size, scale, device in icon_sizes:
        # Calculate actual pixel size
        actual_size = int(base_size * scale)

        # Resize the image with high quality
        resized = source_img.resize((actual_size, actual_size), Image.Resampling.LANCZOS)

        # Add rounded corners for non-marketing icons
        if device != "ios-marketing":
            final_img = add_rounded_corners(resized)
        else:
            final_img = resized

        # Generate filename
        if device == "ios-marketing":
            filename = f"icon-ios-marketing-1024x1024@1x.png"
        else:
            size_str = str(int(base_size)) if base_size == int(base_size) else str(base_size).replace('.', '_')
            filename = f"icon-{device}-{size_str}x{size_str}@{scale}x.png"

        output_path = os.path.join(output_dir, filename)

        # Save the icon
        final_img.save(output_path, 'PNG', optimize=True)
        print(f"✓ Generated: {filename} ({actual_size}x{actual_size}px)")

    print(f"\n✨ All icons generated successfully!")
    print(f"📁 Output directory: {output_dir}")

if __name__ == "__main__":
    generate_icon_set()
