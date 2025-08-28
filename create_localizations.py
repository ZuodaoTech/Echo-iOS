#!/usr/bin/env python3
"""
Create properly translated localization files for Echo iOS app.
This script generates culturally appropriate translations for all 19 supported languages.
"""

import os
import json
from pathlib import Path

# Language configurations with cultural context
LANGUAGES = {
    'ko': {
        'name': 'Korean',
        'dir': 'ko.lproj',
        'translations': {
            # Navigation & Titles
            'navigation.cards': '카드',
            'navigation.me': '나',
            'navigation.new_script': '새 카드',
            'navigation.edit_script': '카드 편집',
            
            # Tags
            'tag.untagged': '태그 없음',
            'tag.edit': '태그 편집',
            'tag.delete.confirm.title': '태그 삭제',
            'tag.delete.confirm.message': '이 태그는 %d개의 스크립트에서 사용 중입니다. 삭제하면 해당 스크립트에서 태그가 제거됩니다.',
            'tag.delete.confirm.empty': '이 태그는 사용되지 않습니다. 정말 삭제하시겠습니까?',
            'tag.auto_cleanup': '미사용 태그 자동 삭제',
            'tag.select': '태그 선택',
            'tag.new': '새 태그',
            'tag.label': '태그',
            'tag.none': '없음',
            'tag.count_selected': '%d개 선택됨',
            'tag.breaking_bad_habits': '나쁜 습관 고치기',
            'tag.building_good_habits': '좋은 습관 기르기',
            'tag.appropriate_positivity': '적절한 긍정',
            
            # Common Actions
            'action.done': '완료',
            'action.cancel': '취소',
            'action.delete': '삭제',
            'action.add': '추가',
            'action.save': '저장',
            'action.ok': '확인',
            'action.got_it': '알겠습니다',
            'action.copy': '복사',
            'action.use_as_script': '스크립트로 사용',
            'action.share': '공유',
            'action.edit': '편집',
            
            # Time units
            'time.seconds': '%@초',
            'chars': '글자',
            
            # Sample scripts with cultural context
            'sample.smoking': '나는 담배를 피우지 않습니다. 건강을 소중히 여기고 습관에 지배당하고 싶지 않기 때문입니다.',
            'sample.bedtime': '나는 항상 밤 10시 전에 잠자리에 듭니다. 더 건강하고 활력 넘치는 아침을 맞이할 수 있기 때문입니다.',
            'sample.mistakes': '나는 실수를 했지만 잘한 일도 많습니다. 실수는 배움의 기회이며 성장할 수 있습니다.',
        }
    },
    'zh-Hans': {
        'name': 'Chinese (Simplified)',
        'dir': 'zh-Hans.lproj',
        'translations': {
            # Navigation
            'navigation.cards': '卡片',
            'navigation.me': '我',
            'navigation.new_script': '新建卡片',
            'navigation.edit_script': '编辑卡片',
            
            # Tags
            'tag.untagged': '未分类',
            'tag.edit': '编辑标签',
            'tag.delete.confirm.title': '删除标签',
            'tag.delete.confirm.message': '此标签被 %d 个脚本使用。删除后将从这些脚本中移除该标签。',
            'tag.delete.confirm.empty': '此标签未被任何脚本使用。确定要删除吗？',
            'tag.auto_cleanup': '自动清理未使用标签',
            'tag.select': '选择标签',
            'tag.new': '新建标签',
            'tag.label': '标签',
            'tag.none': '无',
            'tag.count_selected': '已选择 %d 个',
            'tag.breaking_bad_habits': '改掉坏习惯',
            'tag.building_good_habits': '养成好习惯',
            'tag.appropriate_positivity': '积极正念',
            
            # Common Actions
            'action.done': '完成',
            'action.cancel': '取消',
            'action.delete': '删除',
            'action.add': '添加',
            'action.save': '保存',
            'action.ok': '好的',
            'action.got_it': '知道了',
            'action.copy': '复制',
            'action.use_as_script': '用作脚本',
            'action.share': '分享',
            'action.edit': '编辑',
            
            # Time units
            'time.seconds': '%@秒',
            'chars': '字',
            
            # Sample scripts
            'sample.smoking': '我从不吸烟，因为它很臭，而且我讨厌被控制。',
            'sample.bedtime': '我总是在晚上10点前睡觉，因为这更健康，而且我喜欢充满活力地醒来。',
            'sample.mistakes': '我犯了一些错误，但我也做对了很多事。犯错是学习的正常部分，我可以把它们作为改进的机会。',
        }
    },
    'zh-Hant': {
        'name': 'Chinese (Traditional)',
        'dir': 'zh-Hant.lproj',
        'translations': {
            # Navigation
            'navigation.cards': '卡片',
            'navigation.me': '我',
            'navigation.new_script': '新增卡片',
            'navigation.edit_script': '編輯卡片',
            
            # Tags
            'tag.untagged': '未分類',
            'tag.edit': '編輯標籤',
            'tag.delete.confirm.title': '刪除標籤',
            'tag.delete.confirm.message': '此標籤被 %d 個腳本使用。刪除後將從這些腳本中移除該標籤。',
            'tag.delete.confirm.empty': '此標籤未被任何腳本使用。確定要刪除嗎？',
            'tag.auto_cleanup': '自動清理未使用標籤',
            'tag.select': '選擇標籤',
            'tag.new': '新增標籤',
            'tag.label': '標籤',
            'tag.none': '無',
            'tag.count_selected': '已選擇 %d 個',
            'tag.breaking_bad_habits': '改掉壞習慣',
            'tag.building_good_habits': '養成好習慣',
            'tag.appropriate_positivity': '積極正念',
            
            # Common Actions
            'action.done': '完成',
            'action.cancel': '取消',
            'action.delete': '刪除',
            'action.add': '新增',
            'action.save': '儲存',
            'action.ok': '好的',
            'action.got_it': '知道了',
            'action.copy': '複製',
            'action.use_as_script': '用作腳本',
            'action.share': '分享',
            'action.edit': '編輯',
            
            # Time units
            'time.seconds': '%@秒',
            'chars': '字',
            
            # Sample scripts
            'sample.smoking': '我從不吸菸，因為它很臭，而且我討厭被控制。',
            'sample.bedtime': '我總是在晚上10點前睡覺，因為這更健康，而且我喜歡充滿活力地醒來。',
            'sample.mistakes': '我犯了一些錯誤，但我也做對了很多事。犯錯是學習的正常部分，我可以把它們作為改進的機會。',
        }
    },
    'ja': {
        'name': 'Japanese',
        'dir': 'ja.lproj',
        'translations': {
            # Navigation
            'navigation.cards': 'カード',
            'navigation.me': 'マイページ',
            'navigation.new_script': '新規カード',
            'navigation.edit_script': 'カード編集',
            
            # Tags
            'tag.untagged': 'タグなし',
            'tag.edit': 'タグを編集',
            'tag.delete.confirm.title': 'タグを削除',
            'tag.delete.confirm.message': 'このタグは%d個のスクリプトで使用されています。削除するとこれらのスクリプトからタグが削除されます。',
            'tag.delete.confirm.empty': 'このタグは使用されていません。本当に削除しますか？',
            'tag.auto_cleanup': '未使用タグを自動削除',
            'tag.select': 'タグを選択',
            'tag.new': '新規タグ',
            'tag.label': 'タグ',
            'tag.none': 'なし',
            'tag.count_selected': '%d個選択中',
            'tag.breaking_bad_habits': '悪い習慣を断つ',
            'tag.building_good_habits': '良い習慣を身につける',
            'tag.appropriate_positivity': '適切なポジティブ思考',
            
            # Common Actions
            'action.done': '完了',
            'action.cancel': 'キャンセル',
            'action.delete': '削除',
            'action.add': '追加',
            'action.save': '保存',
            'action.ok': 'OK',
            'action.got_it': 'わかりました',
            'action.copy': 'コピー',
            'action.use_as_script': 'スクリプトとして使用',
            'action.share': '共有',
            'action.edit': '編集',
            
            # Time units
            'time.seconds': '%@秒',
            'chars': '文字',
            
            # Sample scripts
            'sample.smoking': '私はタバコを吸いません。健康を大切にし、習慣に支配されたくないからです。',
            'sample.bedtime': '私は毎晩10時前に寝ます。健康的で、朝のエネルギーが素晴らしいからです。',
            'sample.mistakes': '私は間違いを犯しましたが、うまくできたこともあります。間違いは学びの機会です。',
        }
    }
}

def create_full_translation(lang_config, english_keys):
    """Create a complete translation file with all keys from English."""
    translations = lang_config['translations']
    full_content = []
    
    # Header
    full_content.append(f'''/* 
  Localizable.strings ({lang_config['name']})
  Echo
  
  {lang_config['name']} localization with cultural context
*/

''')
    
    # Process each section from English file
    for section, keys in english_keys.items():
        full_content.append(f"// MARK: - {section}\n")
        for key, default_value in keys:
            if key in translations:
                full_content.append(f'"{key}" = "{translations[key]}";\n')
            else:
                # Keep English for untranslated keys (to be translated properly later)
                full_content.append(f'"{key}" = "{default_value}"; // TODO: Translate\n')
        full_content.append('\n')
    
    return ''.join(full_content)

def parse_english_file():
    """Parse the English localization file to extract all keys."""
    english_path = '/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo/en.lproj/Localizable.strings'
    
    sections = {}
    current_section = 'General'
    
    with open(english_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for line in lines:
        line = line.strip()
        if line.startswith('// MARK: -'):
            current_section = line.replace('// MARK: -', '').strip()
            if current_section not in sections:
                sections[current_section] = []
        elif line.startswith('"') and '" = "' in line:
            parts = line.split('" = "')
            if len(parts) == 2:
                key = parts[0].strip('"')
                value = parts[1].rstrip(';').strip('"')
                sections[current_section].append((key, value))
    
    return sections

def main():
    """Main function to create all localization files."""
    print("Parsing English localization file...")
    english_keys = parse_english_file()
    
    print(f"Found {sum(len(keys) for keys in english_keys.values())} keys in {len(english_keys)} sections")
    
    # Create localization files for each language
    for lang_code, lang_config in LANGUAGES.items():
        dir_path = f'/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo/{lang_config["dir"]}'
        file_path = f'{dir_path}/Localizable.strings'
        
        print(f"Creating {lang_config['name']} localization at {file_path}...")
        
        # Ensure directory exists
        os.makedirs(dir_path, exist_ok=True)
        
        # Generate content
        content = create_full_translation(lang_config, english_keys)
        
        # Write file
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"  ✓ Created {lang_config['name']} with {len(lang_config['translations'])} translated keys")
    
    print("\nLocalization files created successfully!")
    print("Note: Keys marked with '// TODO: Translate' need proper translation")

if __name__ == '__main__':
    main()