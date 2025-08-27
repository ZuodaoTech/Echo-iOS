#!/usr/bin/env python3
"""
Script to update all localization files with new keys for Echo iOS app
"""

import os
import re

# Base directory for localization files
BASE_DIR = "/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo"

# New keys to add (English as base)
NEW_KEYS = {
    "dev.title": {
        "en": "🛠️ Developer Tools",
        "zh-Hans": "🛠️ 开发者工具",
        "zh-Hant": "🛠️ 開發者工具",
        "es": "🛠️ Herramientas de desarrollador",
        "fr": "🛠️ Outils de développement",
        "de": "🛠️ Entwickler-Tools",
        "ja": "🛠️ 開発者ツール",
        "ko": "🛠️ 개발자 도구",
        "pt": "🛠️ Ferramentas do desenvolvedor",
        "ru": "🛠️ Инструменты разработчика",
        "it": "🛠️ Strumenti per sviluppatori",
        "nl": "🛠️ Ontwikkelaarstools",
        "sv": "🛠️ Utvecklarverktyg",
        "nb": "🛠️ Utviklerverktøy",
        "da": "🛠️ Udviklerværktøjer",
        "pl": "🛠️ Narzędzia deweloperskie",
        "tr": "🛠️ Geliştirici Araçları",
        "ar": "🛠️ أدوات المطور",
        "fi": "🛠️ Kehittäjätyökalut"
    },
    "dev.warning": {
        "en": "⚠️ Display Language requires app restart to take effect.",
        "zh-Hans": "⚠️ 显示语言需要重启应用才能生效。",
        "zh-Hant": "⚠️ 顯示語言需要重啟應用才能生效。",
        "es": "⚠️ El idioma de visualización requiere reiniciar la aplicación.",
        "fr": "⚠️ Le changement de langue nécessite un redémarrage.",
        "de": "⚠️ Anzeigesprache erfordert Neustart der App.",
        "ja": "⚠️ 表示言語の変更にはアプリの再起動が必要です。",
        "ko": "⚠️ 표시 언어 변경은 앱 재시작이 필요합니다.",
        "pt": "⚠️ Mudança de idioma requer reiniciar o aplicativo.",
        "ru": "⚠️ Для изменения языка требуется перезапуск.",
        "it": "⚠️ Cambiare lingua richiede il riavvio dell'app.",
        "nl": "⚠️ Taalwijziging vereist herstart van de app.",
        "sv": "⚠️ Språkändring kräver omstart av appen.",
        "nb": "⚠️ Språkendring krever omstart av appen.",
        "da": "⚠️ Sprogændring kræver genstart af appen.",
        "pl": "⚠️ Zmiana języka wymaga ponownego uruchomienia.",
        "tr": "⚠️ Dil değişikliği uygulama yeniden başlatma gerektirir.",
        "ar": "⚠️ تغيير اللغة يتطلب إعادة تشغيل التطبيق.",
        "fi": "⚠️ Kielen vaihto vaatii sovelluksen uudelleenkäynnistyksen."
    },
    "dev.destructive_actions": {
        "en": "⚠️ Destructive Actions",
        "zh-Hans": "⚠️ 破坏性操作",
        "zh-Hant": "⚠️ 破壞性操作",
        "es": "⚠️ Acciones destructivas",
        "fr": "⚠️ Actions destructives",
        "de": "⚠️ Destruktive Aktionen",
        "ja": "⚠️ 破壊的な操作",
        "ko": "⚠️ 파괴적 작업",
        "pt": "⚠️ Ações destrutivas",
        "ru": "⚠️ Разрушительные действия",
        "it": "⚠️ Azioni distruttive",
        "nl": "⚠️ Destructieve acties",
        "sv": "⚠️ Destruktiva åtgärder",
        "nb": "⚠️ Destruktive handlinger",
        "da": "⚠️ Destruktive handlinger",
        "pl": "⚠️ Akcje destrukcyjne",
        "tr": "⚠️ Yıkıcı işlemler",
        "ar": "⚠️ إجراءات تدميرية",
        "fi": "⚠️ Tuhoavat toiminnot"
    },
    "dev.destructive_warning": {
        "en": "These actions are destructive and cannot be undone.",
        "zh-Hans": "这些操作具有破坏性且无法撤销。",
        "zh-Hant": "這些操作具有破壞性且無法撤銷。",
        "es": "Estas acciones son destructivas y no se pueden deshacer.",
        "fr": "Ces actions sont destructives et irréversibles.",
        "de": "Diese Aktionen sind destruktiv und können nicht rückgängig gemacht werden.",
        "ja": "これらの操作は破壊的で元に戻すことができません。",
        "ko": "이러한 작업은 파괴적이며 되돌릴 수 없습니다.",
        "pt": "Essas ações são destrutivas e não podem ser desfeitas.",
        "ru": "Эти действия разрушительны и не могут быть отменены.",
        "it": "Queste azioni sono distruttive e non possono essere annullate.",
        "nl": "Deze acties zijn destructief en kunnen niet ongedaan worden gemaakt.",
        "sv": "Dessa åtgärder är destruktiva och kan inte ångras.",
        "nb": "Disse handlingene er destruktive og kan ikke angres.",
        "da": "Disse handlinger er destruktive og kan ikke fortrydes.",
        "pl": "Te akcje są destrukcyjne i nie można ich cofnąć.",
        "tr": "Bu işlemler yıkıcıdır ve geri alınamaz.",
        "ar": "هذه الإجراءات مدمرة ولا يمكن التراجع عنها.",
        "fi": "Nämä toiminnot ovat tuhoavia eikä niitä voi kumota."
    },
    "dev.clear_icloud": {
        "en": "Clear iCloud Data",
        "zh-Hans": "清除 iCloud 数据",
        "zh-Hant": "清除 iCloud 資料",
        "es": "Borrar datos de iCloud",
        "fr": "Effacer les données iCloud",
        "de": "iCloud-Daten löschen",
        "ja": "iCloudデータを消去",
        "ko": "iCloud 데이터 지우기",
        "pt": "Limpar dados do iCloud",
        "ru": "Очистить данные iCloud",
        "it": "Cancella dati iCloud",
        "nl": "iCloud-gegevens wissen",
        "sv": "Rensa iCloud-data",
        "nb": "Slett iCloud-data",
        "da": "Slet iCloud-data",
        "pl": "Wyczyść dane iCloud",
        "tr": "iCloud verilerini temizle",
        "ar": "مسح بيانات iCloud",
        "fi": "Tyhjennä iCloud-tiedot"
    },
    "dev.clear_icloud.confirm": {
        "en": "Clear iCloud Data?",
        "zh-Hans": "清除 iCloud 数据？",
        "zh-Hant": "清除 iCloud 資料？",
        "es": "¿Borrar datos de iCloud?",
        "fr": "Effacer les données iCloud ?",
        "de": "iCloud-Daten löschen?",
        "ja": "iCloudデータを消去しますか？",
        "ko": "iCloud 데이터를 지우시겠습니까?",
        "pt": "Limpar dados do iCloud?",
        "ru": "Очистить данные iCloud?",
        "it": "Cancellare dati iCloud?",
        "nl": "iCloud-gegevens wissen?",
        "sv": "Rensa iCloud-data?",
        "nb": "Slette iCloud-data?",
        "da": "Slette iCloud-data?",
        "pl": "Wyczyścić dane iCloud?",
        "tr": "iCloud verileri temizlensin mi?",
        "ar": "مسح بيانات iCloud؟",
        "fi": "Tyhjennä iCloud-tiedot?"
    }
}

def update_localization_file(lang_code, new_keys):
    """Update a single localization file with new keys"""
    file_path = os.path.join(BASE_DIR, f"{lang_code}.lproj", "Localizable.strings")
    
    if not os.path.exists(file_path):
        print(f"Warning: File not found: {file_path}")
        return
    
    # Read existing content
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if developer tools section already exists
    if "// MARK: - Developer Tools" in content:
        print(f"Developer Tools section already exists in {lang_code}")
        return
    
    # Prepare new content to add
    new_content = "\n// MARK: - Developer Tools\n"
    for key, translations in new_keys.items():
        translation = translations.get(lang_code, translations['en'])  # Fallback to English
        new_content += f'"{key}" = "{translation}";\n'
    
    # Add before the last closing (if file ends properly)
    if content.rstrip().endswith(';'):
        content = content.rstrip() + new_content
    else:
        content = content + new_content
    
    # Write back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Updated {lang_code}.lproj/Localizable.strings")

def main():
    # Language codes
    languages = [
        'en', 'zh-Hans', 'zh-Hant', 'es', 'fr', 'de', 'ja', 'ko',
        'pt', 'ru', 'it', 'nl', 'sv', 'nb', 'da', 'pl', 'tr', 'ar', 'fi'
    ]
    
    for lang in languages:
        update_localization_file(lang, NEW_KEYS)
    
    print("\nLocalization update complete!")

if __name__ == "__main__":
    main()