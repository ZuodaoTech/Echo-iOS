#!/usr/bin/env python3
"""
Script to synchronize all localization files with English master file
Ensures all language files have the same keys
"""

import os
import re
from collections import OrderedDict

BASE_DIR = "/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo"

def parse_localization_file(file_path):
    """Parse a .strings file and return ordered dict of keys and values"""
    keys = OrderedDict()
    current_section = None
    
    if not os.path.exists(file_path):
        return keys, []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
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

def update_language_file(lang_code, master_keys):
    """Update a language file to have all keys from master (English)"""
    file_path = os.path.join(BASE_DIR, f"{lang_code}.lproj", "Localizable.strings")
    
    # Parse existing file
    existing_keys, original_lines = parse_localization_file(file_path)
    
    # Track what keys are missing
    missing_keys = []
    for key in master_keys:
        if key not in existing_keys:
            missing_keys.append(key)
    
    if not missing_keys:
        print(f"✅ {lang_code}: All keys present ({len(existing_keys)} keys)")
        return
    
    print(f"📝 {lang_code}: Adding {len(missing_keys)} missing keys")
    
    # Read the file content
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add missing keys at the end, grouped by section
    additions = []
    current_section = None
    
    for key in missing_keys:
        master_info = master_keys[key]
        
        # Add section header if changed
        if master_info['section'] != current_section:
            if master_info['section']:
                additions.append("")
                additions.append(master_info['section'])
            current_section = master_info['section']
        
        # For new keys, check if we have translations
        translated_value = get_translation_for_key(key, lang_code, master_info['value'])
        additions.append(f'"{key}" = "{translated_value}";')
    
    # Append to file
    if additions:
        # Remove trailing empty lines
        content = content.rstrip()
        
        # Add new content
        content += "\n" + "\n".join(additions) + "\n"
        
        # Write back
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)

def get_translation_for_key(key, lang_code, english_value):
    """Get translation for a key, with specific translations for known keys"""
    
    # Placeholder keys - these should be translated
    placeholders = {
        "tag.search.placeholder": {
            "zh-Hans": "搜索标签...",
            "zh-Hant": "搜尋標籤...",
            "ja": "タグを検索...",
            "ko": "태그 검색...",
            "es": "Buscar etiquetas...",
            "fr": "Rechercher des tags...",
            "de": "Tags suchen...",
            "pt": "Pesquisar tags...",
            "ru": "Поиск тегов...",
            "it": "Cerca tag...",
            "nl": "Zoek tags...",
            "sv": "Sök taggar...",
            "nb": "Søk etter tagger...",
            "da": "Søg efter tags...",
            "pl": "Szukaj tagów...",
            "tr": "Etiket ara...",
            "ar": "البحث عن العلامات...",
            "fi": "Hae tageja...",
            "hi": "टैग खोजें..."
        },
        "tag.name.placeholder": {
            "zh-Hans": "标签名称",
            "zh-Hant": "標籤名稱",
            "ja": "タグ名",
            "ko": "태그 이름",
            "es": "Nombre de etiqueta",
            "fr": "Nom du tag",
            "de": "Tag-Name",
            "pt": "Nome da tag",
            "ru": "Название тега",
            "it": "Nome tag",
            "nl": "Tag naam",
            "sv": "Taggnamn",
            "nb": "Taggnavn",
            "da": "Tag navn",
            "pl": "Nazwa tagu",
            "tr": "Etiket adı",
            "ar": "اسم العلامة",
            "fi": "Tagin nimi",
            "hi": "टैग का नाम"
        }
    }
    
    # Check if we have a specific translation
    if key in placeholders and lang_code in placeholders[key]:
        return placeholders[key][lang_code]
    
    # Default to English value for unknown translations
    return english_value

def main():
    # Parse English master file
    en_file = os.path.join(BASE_DIR, "en.lproj", "Localizable.strings")
    master_keys, _ = parse_localization_file(en_file)
    
    print(f"📖 Master file has {len(master_keys)} keys")
    
    # All language codes
    languages = [
        'zh-Hans', 'zh-Hant', 'es', 'fr', 'de', 'ja', 'ko',
        'pt', 'ru', 'it', 'nl', 'sv', 'nb', 'da', 'pl', 'tr', 'ar', 'fi', 'hi'
    ]
    
    # Update each language file
    for lang in languages:
        update_language_file(lang, master_keys)
    
    print("\n✨ Localization synchronization complete!")

if __name__ == "__main__":
    main()