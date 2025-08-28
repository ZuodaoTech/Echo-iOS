#!/usr/bin/env python3
"""
Fix all localization files to be consistent with English master
"""

import os
import re
from collections import OrderedDict

BASE_DIR = "/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo"

def parse_localization_file(file_path):
    """Parse a .strings file and return content and keys"""
    if not os.path.exists(file_path):
        return None, None
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract all key-value pairs
    keys = OrderedDict()
    for match in re.finditer(r'^"([^"]+)"\s*=\s*"(.*)";', content, re.MULTILINE):
        key = match.group(1)
        value = match.group(2)
        keys[key] = value
    
    return content, keys

def remove_unused_keys(file_path, unused_keys):
    """Remove unused keys from a localization file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    skip_next_empty = False
    
    for line in lines:
        # Check if this line contains an unused key
        should_skip = False
        for key in unused_keys:
            if f'"{key}"' in line:
                should_skip = True
                skip_next_empty = True
                break
        
        if not should_skip:
            # Don't add empty lines after removed keys
            if skip_next_empty and line.strip() == "":
                skip_next_empty = False
            else:
                new_lines.append(line)
                skip_next_empty = False
    
    # Write back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

def main():
    # Keys that should be removed (not used in code)
    unused_keys = [
        "tag.now",
        "tag.max_now_cards", 
        "tag.now_limit_reached",
        "tag.now_limit_message"
    ]
    
    print("Removing unused keys from all localization files...")
    print(f"Keys to remove: {', '.join(unused_keys)}")
    print()
    
    # Process all language files
    for filename in os.listdir(BASE_DIR):
        if filename.endswith(".lproj"):
            file_path = os.path.join(BASE_DIR, filename, "Localizable.strings")
            if os.path.exists(file_path):
                lang = filename.replace(".lproj", "")
                
                # Check if file has any unused keys
                content, keys = parse_localization_file(file_path)
                if keys is None:
                    continue
                    
                has_unused = any(key in keys for key in unused_keys)
                
                if has_unused:
                    print(f"  Cleaning {lang}...")
                    remove_unused_keys(file_path, unused_keys)
                else:
                    print(f"  ✅ {lang} - already clean")
    
    print("\n✨ Done! All files cleaned.")

if __name__ == "__main__":
    main()