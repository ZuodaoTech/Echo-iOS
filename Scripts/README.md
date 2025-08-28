# Echo iOS Utility Scripts

This directory contains utility scripts for maintaining and developing the Echo iOS app.

## Directory Structure

```
Scripts/
├── Localization/       # Localization management tools
│   └── localization_manager.py
└── README.md          # This file
```

## Localization Scripts

### localization_manager.py

A comprehensive tool for managing all aspects of app localization.

#### Features:
- **Check** - Verify all localization files for consistency and completeness
- **Sync** - Synchronize all language files with the English master
- **Audit** - Find hardcoded strings in Swift files that should be localized
- **Clean** - Remove duplicate keys and unused translations
- **Stats** - Display localization statistics and coverage

#### Usage:

```bash
# Check all localization files for issues
python3 Scripts/Localization/localization_manager.py check

# Sync all language files with English master
python3 Scripts/Localization/localization_manager.py sync

# Find hardcoded strings in Swift files
python3 Scripts/Localization/localization_manager.py audit

# Remove duplicates and clean up files
python3 Scripts/Localization/localization_manager.py clean

# Show localization statistics
python3 Scripts/Localization/localization_manager.py stats
```

#### Supported Languages:
The script manages localization for 19 languages:
- English (en) - Master file
- Chinese Simplified (zh-Hans)
- Chinese Traditional (zh-Hant)
- Spanish (es)
- French (fr)
- German (de)
- Japanese (ja)
- Korean (ko)
- Portuguese (pt)
- Russian (ru)
- Italian (it)
- Dutch (nl)
- Swedish (sv)
- Norwegian (nb)
- Danish (da)
- Polish (pl)
- Turkish (tr)
- Arabic (ar)
- Finnish (fi)
- Hindi (hi)

#### When to Use:

1. **Before Release**: Run `check` to ensure all translations are complete
2. **After Adding New Strings**: Run `sync` to add new keys to all language files
3. **Code Review**: Run `audit` to find any hardcoded strings
4. **Maintenance**: Run `clean` periodically to remove duplicates
5. **Reporting**: Run `stats` to get translation coverage metrics

## Adding New Scripts

When adding new utility scripts:

1. Create a subdirectory for the script category if it doesn't exist
2. Add comprehensive documentation in the script header
3. Update this README with usage instructions
4. Make scripts executable: `chmod +x script_name.py`
5. Use consistent error handling and exit codes

## Requirements

All Python scripts require Python 3.6+ and use only standard library modules (no external dependencies).

## Contributing

When modifying scripts:
- Maintain backward compatibility
- Add unit tests if the script becomes complex
- Update documentation for any new features
- Follow PEP 8 style guidelines for Python code