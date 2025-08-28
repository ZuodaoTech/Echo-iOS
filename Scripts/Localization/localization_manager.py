#!/usr/bin/env python3
"""
Echo iOS Localization Manager
A comprehensive tool for managing localization files in the Echo iOS app.

Usage:
    python3 localization_manager.py check     # Check all localization files for issues
    python3 localization_manager.py sync      # Sync all language files with English master
    python3 localization_manager.py audit     # Find hardcoded strings in Swift files
    python3 localization_manager.py clean     # Remove duplicates and unused keys
    python3 localization_manager.py stats     # Show localization statistics
"""

import os
import re
import sys
import json
from collections import OrderedDict, defaultdict
from typing import Dict, List, Tuple, Optional

# Configuration
BASE_DIR = "/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo"
SWIFT_DIR = "/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo"

# All supported languages
LANGUAGES = [
    ('en', 'English'),
    ('zh-Hans', 'Chinese Simplified'),
    ('zh-Hant', 'Chinese Traditional'),
    ('es', 'Spanish'),
    ('fr', 'French'),
    ('de', 'German'),
    ('ja', 'Japanese'),
    ('ko', 'Korean'),
    ('pt', 'Portuguese'),
    ('ru', 'Russian'),
    ('it', 'Italian'),
    ('nl', 'Dutch'),
    ('sv', 'Swedish'),
    ('nb', 'Norwegian'),
    ('da', 'Danish'),
    ('pl', 'Polish'),
    ('tr', 'Turkish'),
    ('ar', 'Arabic'),
    ('fi', 'Finnish'),
    ('hi', 'Hindi')
]

class LocalizationManager:
    def __init__(self):
        self.base_dir = BASE_DIR
        self.swift_dir = SWIFT_DIR
        
    def parse_localization_file(self, file_path: str) -> Tuple[OrderedDict, List[str]]:
        """Parse a .strings file and return keys and original lines"""
        keys = OrderedDict()
        lines = []
        
        if not os.path.exists(file_path):
            return keys, lines
        
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        current_section = None
        for i, line in enumerate(lines):
            # Track section comments
            if line.strip().startswith("// MARK:"):
                current_section = line.strip()
            
            # Parse key-value pairs
            match = re.match(r'^"([^"]+)"\s*=\s*"(.*)";', line)
            if match:
                key = match.group(1)
                value = match.group(2)
                keys[key] = {
                    'value': value,
                    'section': current_section,
                    'line': i
                }
        
        return keys, lines
    
    def check_all_files(self):
        """Check all localization files for issues"""
        print("\n" + "="*80)
        print("LOCALIZATION FILE CHECK")
        print("="*80)
        
        # Parse English master file
        en_file = os.path.join(self.base_dir, "en.lproj", "Localizable.strings")
        master_keys, _ = self.parse_localization_file(en_file)
        
        print(f"\n📖 English Master: {len(master_keys)} keys")
        
        issues_found = False
        all_counts = []
        
        for lang_code, lang_name in LANGUAGES[1:]:  # Skip English
            file_path = os.path.join(self.base_dir, f"{lang_code}.lproj", "Localizable.strings")
            lang_keys, _ = self.parse_localization_file(file_path)
            
            if not lang_keys:
                print(f"❌ {lang_name:20} - FILE NOT FOUND")
                issues_found = True
                continue
            
            all_counts.append(len(lang_keys))
            
            # Check for issues
            missing = set(master_keys.keys()) - set(lang_keys.keys())
            extra = set(lang_keys.keys()) - set(master_keys.keys())
            
            if missing or extra:
                print(f"⚠️  {lang_name:20} - {len(lang_keys)} keys", end="")
                if missing:
                    print(f" (missing: {len(missing)})", end="")
                if extra:
                    print(f" (extra: {len(extra)})", end="")
                print()
                issues_found = True
            else:
                print(f"✅ {lang_name:20} - {len(lang_keys)} keys")
        
        # Check consistency
        if len(set(all_counts)) > 1:
            print(f"\n⚠️  INCONSISTENT KEY COUNTS: {set(all_counts)}")
            issues_found = True
        else:
            print(f"\n✅ All files have {all_counts[0] if all_counts else 0} keys")
        
        return not issues_found
    
    def sync_with_master(self):
        """Sync all language files with English master"""
        print("\n" + "="*80)
        print("SYNCING WITH ENGLISH MASTER")
        print("="*80)
        
        # Parse English master
        en_file = os.path.join(self.base_dir, "en.lproj", "Localizable.strings")
        master_keys, _ = self.parse_localization_file(en_file)
        
        print(f"\n📖 Master file has {len(master_keys)} keys")
        
        for lang_code, lang_name in LANGUAGES[1:]:  # Skip English
            file_path = os.path.join(self.base_dir, f"{lang_code}.lproj", "Localizable.strings")
            lang_keys, original_lines = self.parse_localization_file(file_path)
            
            if not lang_keys:
                print(f"⚠️  {lang_name:20} - SKIPPED (file not found)")
                continue
            
            # Find missing keys
            missing = set(master_keys.keys()) - set(lang_keys.keys())
            
            if missing:
                print(f"📝 {lang_name:20} - Adding {len(missing)} missing keys")
                
                # Read file content
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Add missing keys
                additions = []
                current_section = None
                
                for key in sorted(missing):
                    master_info = master_keys[key]
                    
                    # Add section header if needed
                    if master_info['section'] != current_section:
                        if master_info['section']:
                            additions.append("")
                            additions.append(master_info['section'])
                        current_section = master_info['section']
                    
                    # Add key with English value as fallback
                    additions.append(f'"{key}" = "{master_info["value"]}";')
                
                # Append to file
                if additions:
                    content = content.rstrip()
                    content += "\n" + "\n".join(additions) + "\n"
                    
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
            else:
                print(f"✅ {lang_name:20} - Already in sync")
    
    def find_hardcoded_strings(self):
        """Find hardcoded strings in Swift files"""
        print("\n" + "="*80)
        print("HARDCODED STRING AUDIT")
        print("="*80)
        
        hardcoded_found = []
        
        # Patterns to look for
        patterns = [
            (r'Text\("([^"]+)"\)', "Text"),
            (r'\.alert\("([^"]+)"', "Alert title"),
            (r'Button\("([^"]+)"', "Button"),
            (r'\.navigationTitle\("([^"]+)"', "Navigation title"),
            (r'TextField\("([^"]+)"', "TextField placeholder"),
        ]
        
        # Find all Swift files
        for root, dirs, files in os.walk(self.swift_dir):
            for file in files:
                if file.endswith('.swift'):
                    file_path = os.path.join(root, file)
                    
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        lines = content.split('\n')
                    
                    for line_num, line in enumerate(lines, 1):
                        # Skip if already using NSLocalizedString
                        if 'NSLocalizedString' in line:
                            continue
                        
                        for pattern, ui_type in patterns:
                            matches = re.finditer(pattern, line)
                            for match in matches:
                                text = match.group(1)
                                # Skip system symbols and debug strings
                                if not text.startswith('system') and not text.startswith('print'):
                                    relative_path = os.path.relpath(file_path, self.swift_dir)
                                    hardcoded_found.append({
                                        'file': relative_path,
                                        'line': line_num,
                                        'type': ui_type,
                                        'text': text
                                    })
        
        if hardcoded_found:
            print(f"\n⚠️  Found {len(hardcoded_found)} hardcoded strings:\n")
            for item in hardcoded_found[:20]:  # Show first 20
                print(f"  {item['file']}:{item['line']} - {item['type']}: \"{item['text']}\"")
            
            if len(hardcoded_found) > 20:
                print(f"\n  ... and {len(hardcoded_found) - 20} more")
        else:
            print("\n✅ No hardcoded strings found!")
        
        return hardcoded_found
    
    def remove_duplicates(self):
        """Remove duplicate keys from all localization files"""
        print("\n" + "="*80)
        print("REMOVING DUPLICATE KEYS")
        print("="*80)
        
        for lang_code, lang_name in LANGUAGES:
            file_path = os.path.join(self.base_dir, f"{lang_code}.lproj", "Localizable.strings")
            
            if not os.path.exists(file_path):
                continue
            
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            seen_keys = set()
            new_lines = []
            removed_count = 0
            
            for line in lines:
                match = re.match(r'^"([^"]+)"\s*=\s*".*";', line)
                if match:
                    key = match.group(1)
                    if key in seen_keys:
                        removed_count += 1
                        continue
                    seen_keys.add(key)
                
                new_lines.append(line)
            
            if removed_count > 0:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(new_lines)
                print(f"  {lang_name:20} - Removed {removed_count} duplicates")
            else:
                print(f"  {lang_name:20} - No duplicates")
    
    def show_statistics(self):
        """Show localization statistics"""
        print("\n" + "="*80)
        print("LOCALIZATION STATISTICS")
        print("="*80)
        
        total_keys = 0
        total_words = 0
        lang_stats = []
        
        for lang_code, lang_name in LANGUAGES:
            file_path = os.path.join(self.base_dir, f"{lang_code}.lproj", "Localizable.strings")
            keys, _ = self.parse_localization_file(file_path)
            
            if keys:
                word_count = sum(len(info['value'].split()) for info in keys.values())
                lang_stats.append({
                    'name': lang_name,
                    'code': lang_code,
                    'keys': len(keys),
                    'words': word_count
                })
                
                if lang_code == 'en':
                    total_keys = len(keys)
                    total_words = word_count
        
        print(f"\n📊 Total unique keys: {total_keys}")
        print(f"📝 Total words (English): {total_words}")
        print(f"🌍 Languages supported: {len(LANGUAGES)}")
        
        print(f"\n{'Language':<25} {'Code':<10} {'Keys':<10} {'Words':<10}")
        print("-" * 60)
        
        for stat in lang_stats:
            status = "✅" if stat['keys'] == total_keys else f"⚠️ ({stat['keys']})"
            print(f"{stat['name']:<25} {stat['code']:<10} {status:<10} {stat['words']:<10}")

def main():
    """Main entry point"""
    manager = LocalizationManager()
    
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    if command == 'check':
        success = manager.check_all_files()
        sys.exit(0 if success else 1)
    
    elif command == 'sync':
        manager.sync_with_master()
    
    elif command == 'audit':
        hardcoded = manager.find_hardcoded_strings()
        if hardcoded:
            # Save audit report
            report_path = os.path.join(os.path.dirname(BASE_DIR), "localization_audit.json")
            with open(report_path, 'w') as f:
                json.dump(hardcoded, f, indent=2)
            print(f"\n📄 Full report saved to: {report_path}")
    
    elif command == 'clean':
        manager.remove_duplicates()
    
    elif command == 'stats':
        manager.show_statistics()
    
    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)

if __name__ == "__main__":
    main()