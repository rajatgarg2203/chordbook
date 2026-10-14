#!/bin/bash

# Firestore Backup Script
# Run this periodically to backup your cloud database

PROJECT_ID="chordbook-app"
BACKUP_DIR="$HOME/Documents/ChordBook_Backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting Firestore backup..."
echo "Project: $PROJECT_ID"
echo "Backup location: $BACKUP_DIR/firestore_backup_$TIMESTAMP"

# Export Firestore data
# Note: This requires Firebase CLI and proper authentication
# Install: npm install -g firebase-tools
# Login: firebase login

firebase firestore:export "gs://${PROJECT_ID}.appspot.com/backups/firestore_backup_$TIMESTAMP" \
  --project "$PROJECT_ID"

echo "✓ Backup completed: firestore_backup_$TIMESTAMP"
echo "To restore: firebase firestore:import gs://${PROJECT_ID}.appspot.com/backups/firestore_backup_$TIMESTAMP"
