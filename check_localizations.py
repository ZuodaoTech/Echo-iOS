#!/usr/bin/env python3
"""
Comprehensive localization file checker for Echo iOS app
"""

import os
import re
from collections import defaultdict, OrderedDict

BASE_DIR = "/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo"

def check_localization_file(file_path, lang_code):
    """Check a single localization file for issues"""
    issues = []
    keys = OrderedDict()
    duplicates = defaultdict(list)
    line_num = 0
    
    if not os.path.exists(file_path):
        return None, [f"File not found: {file_path}"]
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines, 1):
        line_num = i
        stripped = line.strip()
        
        # Skip empty lines and comments
        if not stripped or stripped.startswith('//') or stripped.startswith('/*'):
            continue
        
        # Check for proper format
        match = re.match(r'^"([^"]+)"\s*=\s*"(.*)";$', stripped)
        if match:
            key = match.group(1)
            value = match.group(2)
            
            # Check for duplicates
            if key in keys:
                duplicates[key].append(line_num)
                if key not in duplicates:
                    duplicates[key].append(keys[key]['line'])
            else:
                keys[key] = {
                    'value': value,
                    'line': line_num
                }
            
            # Check for untranslated values (still in English for non-English files)
            if lang_code != 'en' and lang_code != 'en-US':
                # Common English phrases that indicate untranslated content
                english_indicators = [
                    'Clear iCloud Data', 'Clear All Local Data', 
                    'Remove Duplicate', 'Developer Tools',
                    'Operation Complete', 'Validation Error',
                    'Processing', 'Stopping recording',
                    'Search tags...', 'Tag name',
                    'New Tag', 'Cancel', 'Add', 'Remove'
                ]
                for indicator in english_indicators:
                    if indicator in value and not any(c in value for c in ['%', '@']):
                        issues.append(f"Line {line_num}: Possible untranslated content: '{key}' = '{value}'")
                        break
        elif stripped and not stripped.startswith('*/'):
            # Line should be a valid key-value pair but isn't
            if '=' in stripped:
                issues.append(f"Line {line_num}: Invalid format: {stripped[:50]}...")
    
    # Report duplicates
    for key, lines in duplicates.items():
        if len(lines) > 1:
            issues.append(f"Duplicate key '{key}' found on lines: {', '.join(map(str, lines))}")
    
    return keys, issues

def compare_with_master(master_keys, lang_keys, lang_code):
    """Compare language file with English master"""
    issues = []
    
    # Find missing keys
    missing_keys = set(master_keys.keys()) - set(lang_keys.keys())
    if missing_keys:
        issues.append(f"Missing {len(missing_keys)} keys: {', '.join(sorted(missing_keys)[:5])}...")
    
    # Find extra keys (not in master)
    extra_keys = set(lang_keys.keys()) - set(master_keys.keys())
    if extra_keys:
        issues.append(f"Extra {len(extra_keys)} keys not in English: {', '.join(sorted(extra_keys)[:5])}...")
    
    return issues

def main():
    print("=" * 80)
    print("ECHO iOS LOCALIZATION FILE CHECKER")
    print("=" * 80)
    
    # Parse English master file
    en_file = os.path.join(BASE_DIR, "en.lproj", "Localizable.strings")
    master_keys, en_issues = check_localization_file(en_file, 'en')
    
    print(f"\n📖 ENGLISH MASTER FILE")
    print(f"   Keys: {len(master_keys)}")
    if en_issues:
        print("   ⚠️ Issues found:")
        for issue in en_issues:
            print(f"      - {issue}")
    else:
        print("   ✅ No issues")
    
    # All language codes
    languages = [
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
    
    all_good = True
    summary = []
    
    for lang_code, lang_name in languages:
        file_path = os.path.join(BASE_DIR, f"{lang_code}.lproj", "Localizable.strings")
        lang_keys, file_issues = check_localization_file(file_path, lang_code)
        
        if lang_keys is None:
            print(f"\n❌ {lang_name} ({lang_code}): FILE NOT FOUND")
            all_good = False
            continue
        
        # Compare with master
        comparison_issues = compare_with_master(master_keys, lang_keys, lang_code)
        all_issues = file_issues + comparison_issues
        
        status = "✅" if not all_issues else "⚠️"
        print(f"\n{status} {lang_name} ({lang_code})")
        print(f"   Keys: {len(lang_keys)}")
        
        if all_issues:
            all_good = False
            print("   Issues:")
            for issue in all_issues[:10]:  # Limit to first 10 issues
                print(f"      - {issue}")
            if len(all_issues) > 10:
                print(f"      ... and {len(all_issues) - 10} more issues")
        
        summary.append({
            'lang': lang_code,
            'name': lang_name,
            'keys': len(lang_keys),
            'issues': len(all_issues)
        })
    
    # Print summary table
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"{'Language':<25} {'Code':<12} {'Keys':<10} {'Issues':<10} {'Status'}")
    print("-" * 80)
    
    for item in summary:
        status = "✅ OK" if item['issues'] == 0 else f"⚠️ {item['issues']} issues"
        print(f"{item['name']:<25} {item['lang']:<12} {item['keys']:<10} {item['issues']:<10} {status}")
    
    print("-" * 80)
    
    if all_good:
        print("\n✨ ALL LOCALIZATION FILES ARE VALID!")
    else:
        print("\n⚠️ SOME ISSUES FOUND - Please review above")
    
    # Check for consistency
    key_counts = [item['keys'] for item in summary]
    if len(set(key_counts)) > 1:
        print(f"\n⚠️ INCONSISTENT KEY COUNTS: {set(key_counts)}")
    else:
        print(f"\n✅ All files have consistent key count: {key_counts[0]}")

if __name__ == "__main__":
    main()