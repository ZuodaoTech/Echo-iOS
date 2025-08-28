#!/usr/bin/env python3
"""
Remove duplicate keys from localization files
"""

import os
import re
from collections import OrderedDict

BASE_DIR = "/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo"

def remove_duplicate_keys(file_path):
    """Remove duplicate keys, keeping only the first occurrence"""
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    seen_keys = set()
    new_lines = []
    removed_count = 0
    
    for line in lines:
        # Check if this is a key-value line
        match = re.match(r'^"([^"]+)"\s*=\s*".*";', line)
        if match:
            key = match.group(1)
            if key in seen_keys:
                # Skip duplicate
                removed_count += 1
                continue
            seen_keys.add(key)
        
        new_lines.append(line)
    
    if removed_count > 0:
        # Write back
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
    
    return removed_count

def main():
    print("Removing duplicate keys from all localization files...")
    print()
    
    # Process all language files
    for filename in os.listdir(BASE_DIR):
        if filename.endswith(".lproj"):
            file_path = os.path.join(BASE_DIR, filename, "Localizable.strings")
            if os.path.exists(file_path):
                lang = filename.replace(".lproj", "")
                removed = remove_duplicate_keys(file_path)
                
                if removed > 0:
                    print(f"  {lang}: Removed {removed} duplicate keys")
                else:
                    print(f"  {lang}: ✅ No duplicates")
    
    print("\n✨ Done!")

if __name__ == "__main__":
    main()