import json
import re

def sanitize_for_id(text):
    """Convert text to lowercase, replace spaces/special chars with underscores"""
    # Convert to lowercase
    text = text.lower()
    # Replace spaces and special characters with underscores
    text = re.sub(r'[^a-z0-9]+', '_', text)
    # Remove leading/trailing underscores
    text = text.strip('_')
    return text

def generate_song_id(title, artist_names):
    """Generate ID in format: title_artist"""
    title_part = sanitize_for_id(title)
    # Use first artist if multiple
    artist_part = sanitize_for_id(artist_names[0]) if artist_names else 'unknown'
    return f"{title_part}_{artist_part}"

# Read the JSON file
input_file = '/Users/rajatga/Documents/CascadeProjects/windsurf-project/chordbook/sample_songs/all_songs_converted.json'
output_file = '/Users/rajatga/Documents/CascadeProjects/windsurf-project/chordbook/sample_songs/all_songs_converted.json'

with open(input_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Update IDs for all songs
for song in data['songs']:
    new_id = generate_song_id(song['title'], song['artistNames'])
    song['id'] = new_id
    print(f"{song['title']} - {song['artistNames'][0] if song['artistNames'] else 'Unknown'} -> {new_id}")

# Write back to file
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"\n✓ Updated {len(data['songs'])} song IDs")
print(f"✓ Saved to: {output_file}")
