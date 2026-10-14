# Database Backup Instructions

## Method 1: Using the App (Recommended)
1. Open ChordBook app on your device
2. Go to Settings
3. Tap "Export All Songs (JSON)"
4. Save the file to a safe location
5. This creates a complete backup of all your songs

## Method 2: Manual Database Copy
If you need to backup the raw SQLite database:
1. Connect your device via USB
2. Enable USB debugging
3. Run: `adb shell "run-as com.example.chordbook cat /data/data/com.example.chordbook/app_flutter/chordbook.sqlite" > database_backup.sqlite`

## Restoring from Backup
1. Open ChordBook app
2. Go to Settings
3. Tap "Import Songs (JSON)"
4. Select your backup file
5. All songs will be restored

## Current Backup
- Date: January 5, 2026
- Before adding category field (schema v1 -> v2)
- Use the app's export feature to create your backup now before proceeding
