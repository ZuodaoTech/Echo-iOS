#!/usr/bin/env python3
"""
Comprehensive script to find ALL hardcoded strings in Swift files that should be localized
"""

import os
import re
from pathlib import Path
import json

class LocalizationAuditor:
    def __init__(self, project_path):
        self.project_path = Path(project_path)
        self.hardcoded_strings = []
        self.existing_keys = set()
        self.swift_ui_patterns = [
            # SwiftUI Text views
            (r'Text\s*\(\s*"([^"]+)"\s*\)', 'Text'),
            (r'Text\s*\(\s*"([^"]+)"[^)]*\)', 'Text with modifiers'),
            
            # Button labels
            (r'Button\s*\(\s*"([^"]+)"\s*\)', 'Button label'),
            (r'Button\s*\(\s*"([^"]+)"[^{]*\{', 'Button with action'),
            
            # Labels
            (r'Label\s*\(\s*"([^"]+)"', 'Label'),
            (r'\.navigationTitle\s*\(\s*"([^"]+)"\s*\)', 'Navigation title'),
            (r'\.navigationBarTitle\s*\(\s*"([^"]+)"\s*\)', 'Navigation bar title'),
            
            # Alerts
            (r'\.alert\s*\(\s*"([^"]+)"', 'Alert title'),
            (r'\.confirmationDialog\s*\(\s*"([^"]+)"', 'Confirmation dialog'),
            
            # TextField placeholders
            (r'TextField\s*\(\s*"([^"]+)"', 'TextField placeholder'),
            (r'SecureField\s*\(\s*"([^"]+)"', 'SecureField placeholder'),
            
            # Section headers/footers
            (r'header:\s*\{\s*Text\s*\(\s*"([^"]+)"\s*\)', 'Section header'),
            (r'footer:\s*\{\s*Text\s*\(\s*"([^"]+)"\s*\)', 'Section footer'),
            
            # Picker/Menu items
            (r'Picker\s*\(\s*"([^"]+)"', 'Picker label'),
            (r'Menu\s*\(\s*"([^"]+)"', 'Menu label'),
            
            # TabView items
            (r'\.tabItem\s*\{[^}]*Label\s*\(\s*"([^"]+)"', 'Tab item'),
            
            # Accessibility
            (r'\.accessibilityLabel\s*\(\s*"([^"]+)"\s*\)', 'Accessibility label'),
            (r'\.accessibilityHint\s*\(\s*"([^"]+)"\s*\)', 'Accessibility hint'),
            
            # Error messages
            (r'fatalError\s*\(\s*"([^"]+)"\s*\)', 'Fatal error'),
            
            # String interpolation that might need localization
            (r'"([^"]*\\[^"]*)"', 'String with interpolation'),
        ]
        
        # Patterns to skip (debug, internal, etc.)
        self.skip_patterns = [
            r'^print\(',
            r'^debugPrint\(',
            r'^NSLog\(',
            r'//.*"',  # Comments
            r'case\s+"',  # Enum cases
            r'\.systemName:\s*"',  # SF Symbol names
            r'Image\(systemName:\s*"',  # System images
            r'\.foregroundColor\(',
            r'\.font\(',
            r'DateFormatter',
            r'NumberFormatter',
        ]

    def load_existing_keys(self):
        """Load all existing localization keys from English file"""
        en_file = self.project_path / "Echo" / "en.lproj" / "Localizable.strings"
        if not en_file.exists():
            print(f"Warning: {en_file} not found")
            return
        
        with open(en_file, 'r', encoding='utf-8') as f:
            content = f.read()
            # Extract all keys
            key_pattern = r'"([^"]+)"\s*='
            self.existing_keys = set(re.findall(key_pattern, content))
        
        print(f"Found {len(self.existing_keys)} existing localization keys")

    def should_skip_line(self, line):
        """Check if a line should be skipped"""
        stripped = line.strip()
        for pattern in self.skip_patterns:
            if re.search(pattern, stripped):
                return True
        return False

    def find_hardcoded_strings(self):
        """Find all hardcoded strings in Swift files"""
        views_path = self.project_path / "Echo" / "Views"
        
        # Also check the main app file and other Swift files
        swift_files = list(views_path.rglob("*.swift"))
        swift_files.extend((self.project_path / "Echo").glob("*.swift"))
        
        for swift_file in swift_files:
            if "Preview" in str(swift_file):
                continue
                
            print(f"\nScanning: {swift_file.name}")
            
            with open(swift_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            for line_num, line in enumerate(lines, 1):
                if self.should_skip_line(line):
                    continue
                
                # Check for NSLocalizedString usage
                if 'NSLocalizedString' in line:
                    continue
                
                # Check each pattern
                for pattern, pattern_type in self.swift_ui_patterns:
                    matches = re.findall(pattern, line)
                    for match in matches:
                        # Skip if it's a variable or computation
                        if '\\(' in match or '+' in match:
                            continue
                        # Skip single characters and very short strings
                        if len(match) <= 2 and match not in ['OK', 'No']:
                            continue
                        # Skip number-only strings
                        if match.isdigit():
                            continue
                        # Skip format specifiers alone
                        if match in ['%d', '%@', '%.1f', '%dx']:
                            continue
                            
                        self.hardcoded_strings.append({
                            'file': swift_file.name,
                            'line': line_num,
                            'string': match,
                            'type': pattern_type,
                            'context': line.strip()
                        })

    def analyze_results(self):
        """Analyze and categorize findings"""
        if not self.hardcoded_strings:
            print("\n✅ No hardcoded strings found!")
            return
        
        print(f"\n⚠️  Found {len(self.hardcoded_strings)} hardcoded strings:\n")
        
        # Group by file
        by_file = {}
        for item in self.hardcoded_strings:
            file_name = item['file']
            if file_name not in by_file:
                by_file[file_name] = []
            by_file[file_name].append(item)
        
        # Output findings
        for file_name, items in sorted(by_file.items()):
            print(f"\n📄 {file_name}:")
            for item in sorted(items, key=lambda x: x['line']):
                print(f"  Line {item['line']:4d}: [{item['type']:20s}] \"{item['string']}\"")
                print(f"            Context: {item['context'][:80]}")

    def check_language_completeness(self):
        """Check if all language files have the same keys"""
        print("\n\n🌍 Checking language file completeness...")
        
        base_dir = self.project_path / "Echo"
        lang_dirs = [d for d in base_dir.glob("*.lproj") if d.is_dir()]
        
        all_keys_by_lang = {}
        
        for lang_dir in lang_dirs:
            lang_code = lang_dir.name.replace('.lproj', '')
            strings_file = lang_dir / "Localizable.strings"
            
            if not strings_file.exists():
                print(f"⚠️  {lang_code}: Localizable.strings not found")
                continue
            
            with open(strings_file, 'r', encoding='utf-8') as f:
                content = f.read()
                keys = set(re.findall(r'"([^"]+)"\s*=', content))
                all_keys_by_lang[lang_code] = keys
        
        # Find the language with most keys (should be English)
        max_keys = max(len(keys) for keys in all_keys_by_lang.values())
        reference_lang = [lang for lang, keys in all_keys_by_lang.items() if len(keys) == max_keys][0]
        reference_keys = all_keys_by_lang[reference_lang]
        
        print(f"\n📊 Using {reference_lang} as reference ({len(reference_keys)} keys)")
        print("-" * 60)
        
        for lang, keys in sorted(all_keys_by_lang.items()):
            missing = reference_keys - keys
            extra = keys - reference_keys
            
            status = "✅" if len(missing) == 0 else "❌"
            print(f"{status} {lang:10s}: {len(keys):3d} keys", end="")
            
            if missing:
                print(f" (missing {len(missing)})", end="")
            if extra:
                print(f" (extra {len(extra)})", end="")
            print()
            
            if missing and lang in ['ko', 'zh-Hans', 'ja']:  # Key Asian languages
                print(f"     Missing keys: {list(missing)[:5]}...")

    def generate_report(self):
        """Generate a comprehensive localization report"""
        report = {
            'total_hardcoded': len(self.hardcoded_strings),
            'by_file': {},
            'unique_strings': set(),
            'recommended_keys': []
        }
        
        for item in self.hardcoded_strings:
            report['unique_strings'].add(item['string'])
            
            if item['file'] not in report['by_file']:
                report['by_file'][item['file']] = []
            report['by_file'][item['file']].append({
                'line': item['line'],
                'string': item['string'],
                'type': item['type']
            })
        
        # Generate recommended localization keys
        for string in sorted(report['unique_strings']):
            # Create a key suggestion
            key = string.lower()
            key = re.sub(r'[^a-z0-9]+', '_', key)
            key = key.strip('_')[:30]
            
            report['recommended_keys'].append({
                'string': string,
                'suggested_key': f'ui.{key}',
                'already_localized': string in self.existing_keys
            })
        
        return report

def main():
    project_path = "/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS"
    auditor = LocalizationAuditor(project_path)
    
    print("🔍 Comprehensive Localization Audit Starting...")
    print("=" * 60)
    
    # Load existing keys
    auditor.load_existing_keys()
    
    # Find hardcoded strings
    auditor.find_hardcoded_strings()
    
    # Analyze results
    auditor.analyze_results()
    
    # Check language completeness
    auditor.check_language_completeness()
    
    # Generate report
    report = auditor.generate_report()
    
    print("\n\n📋 Summary Report:")
    print("=" * 60)
    print(f"Total hardcoded strings found: {report['total_hardcoded']}")
    print(f"Unique strings: {len(report['unique_strings'])}")
    print(f"Files with hardcoded strings: {len(report['by_file'])}")
    
    print("\n🔧 Strings that need localization keys:")
    for item in report['recommended_keys']:
        if not item['already_localized']:
            print(f"  \"{item['string']}\" -> {item['suggested_key']}")
    
    # Save detailed report
    report_file = Path(project_path) / "localization_audit_report.json"
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2, default=str)
    print(f"\n💾 Detailed report saved to: {report_file}")

if __name__ == "__main__":
    main()