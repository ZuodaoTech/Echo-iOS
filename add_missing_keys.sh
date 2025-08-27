#!/bin/bash

# Script to add missing localization keys to all language files
# Uses English as fallback for now - can be professionally translated later

BASE_DIR="/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS/Echo"

# New keys to add (with English fallback)
add_keys_to_file() {
    local file=$1
    echo "Updating $file..."
    
    # Check if Developer Tools section already exists
    if grep -q "// MARK: - Developer Tools" "$file"; then
        echo "  Developer Tools section already exists, skipping..."
        return
    fi
    
    # Append new keys
    cat >> "$file" << 'EOF'

// MARK: - Developer Tools
"dev.title" = "🛠️ Developer Tools";
"dev.warning" = "⚠️ Display Language requires app restart to take effect.";
"dev.destructive_actions" = "⚠️ Destructive Actions";
"dev.destructive_warning" = "These actions are destructive and cannot be undone.";
"dev.clear_icloud" = "Clear iCloud Data";
"dev.clear_icloud.confirm" = "Clear iCloud Data?";
"dev.clear_icloud.message" = "This will remove all Echo data from iCloud. Local data will remain intact.";
"dev.clear_local" = "Clear All Local Data";
"dev.clear_local.confirm" = "Clear All Local Data?";
"dev.clear_local.message" = "This will delete ALL scripts, recordings, and tags. This cannot be undone!";
"dev.clear_local.button" = "Delete Everything";
"dev.remove_duplicates" = "Remove Duplicate Tags & Cards";
"dev.remove_duplicates.confirm" = "Remove Duplicates?";
"dev.remove_duplicates.message" = "This will merge duplicate tags and remove duplicate scripts with the same content.";
"dev.remove_duplicates.button" = "Remove";
"dev.operation_complete" = "Operation Complete";
"dev.clear" = "Clear";

// MARK: - Formatting
"format.seconds_of_60" = "%ds / 60s";
"format.repetitions" = "%dx";
"format.progress" = "%d/%d";
"format.plus_count" = "+%d";
"format.interval_seconds" = "%.1fs";

// MARK: - Additional Alerts
"alert.new_tag" = "New Tag";
"alert.remove" = "Remove";
EOF
    
    echo "  Added missing keys to $file"
}

# Process all language files except English (already done)
for lang_dir in "$BASE_DIR"/*.lproj; do
    lang=$(basename "$lang_dir" .lproj)
    
    # Skip English as it's already updated
    if [ "$lang" = "en" ]; then
        continue
    fi
    
    localization_file="$lang_dir/Localizable.strings"
    
    if [ -f "$localization_file" ]; then
        add_keys_to_file "$localization_file"
    else
        echo "Warning: $localization_file not found"
    fi
done

echo "Done! All language files have been updated with English fallback strings."
echo "These can be professionally translated later."