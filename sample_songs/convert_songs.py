#!/usr/bin/env python3
"""
Converts the Songs database file to ChordBook JSON format.
Usage: python3 convert_songs.py
"""

import json
import re
import uuid
from datetime import datetime

def parse_title_line(line):
    """Parse 'Title - Artist (Album)' format"""
    title = None
    artists = []
    album = None
    
    # Remove emoji and special characters at the end
    line = re.sub(r'[🔵🟤🟢❕]+\s*$', '', line).strip()
    # Remove transpose info
    line = re.sub(r'\s*transpose\s*-?\d+\s*', ' ', line, flags=re.IGNORECASE).strip()
    
    # Try to extract album from parentheses at the end
    album_match = re.search(r'\(([^)]+)\)\s*$', line)
    if album_match:
        album = album_match.group(1).strip()
        line = line[:album_match.start()].strip()
    
    # Split by ' - ' to get title and artists
    if ' - ' in line:
        parts = line.split(' - ', 1)
        title = parts[0].strip()
        if len(parts) > 1:
            # Artists might be comma-separated
            artist_str = parts[1].strip()
            # Remove any remaining parenthetical info
            artist_str = re.sub(r'\([^)]*\)', '', artist_str).strip()
            # Clean up artist names
            artists = [a.strip() for a in artist_str.split(',') if a.strip() and not a.strip().lower().startswith('capo')]
    else:
        title = line.strip()
    
    return title, artists, album

def extract_capo(content):
    """Extract capo number from content"""
    # Look for "Capo: X", "Capo X", "capo X" in first few lines
    lines = content.split('\n')[:5]
    for line in lines:
        match = re.search(r'[Cc]apo[:\s]+(\d+)', line)
        if match:
            return int(match.group(1))
    return None

def extract_key(content):
    """Try to extract key from chord patterns"""
    lines = content.split('\n')[:10]
    for line in lines:
        key_match = re.search(r'[Kk]ey[:\s]+([A-G][#b]?m?)', line)
        if key_match:
            return key_match.group(1)
    return None

def is_song_title_line(line, next_lines_text):
    """Check if line is a song title followed by chord/lyric content"""
    line = line.strip()
    if not line or len(line) < 5:
        return False
    if ' - ' not in line:
        return False
    if line.startswith('http') or line.startswith('[') or line.startswith('('):
        return False
    # Reject lines starting with Capo
    if line.lower().startswith('capo'):
        return False
    
    # Get the part before ' - '
    first_part = line.split(' - ')[0].strip()
    
    # Reject if first part looks like a chord or chord pattern
    # Chord patterns: "F", "Am", "C#m", "Verse", "Chorus", "Bridge", etc.
    if re.match(r'^[A-G][#b]?m?7?$', first_part):
        return False
    if re.match(r'^(Verse|Chorus|Bridge|Intro|Outro|Pre-Chorus|Solo)\d*:?', first_part, re.IGNORECASE):
        return False
    # Reject chord progressions like "F - G - C" or "D - Bm" or "Am F G"
    if re.match(r'^[A-G][#b]?m?7?\s*$', first_part):
        return False
    # Reject if it looks like chord notation (short, contains only chord-like chars)
    if re.match(r'^[A-G][#b]?m?7?\s+[A-G#bm7\s]+$', first_part):
        return False
    # Reject if it contains typical chord notation patterns
    if re.match(r'^[A-G][#b]?m?7?\s*-\s*$', first_part):
        return False
    
    # Must have a reasonable title (at least 3 chars, starts with letter)
    if len(first_part) < 3 or not first_part[0].isalpha():
        return False
    
    # Title should have at least one word with 3+ letters (not just chords)
    words = first_part.split()
    has_real_word = any(len(w) >= 3 and not re.match(r'^[A-G][#b]?m?7?$', w) for w in words)
    if not has_real_word:
        return False
    
    # Check if next lines have Capo (strongest indicator) - various formats
    if re.search(r'^[Cc]apo', next_lines_text, re.MULTILINE):
        return True
    # Check for No Capo
    if re.search(r'^[Nn]o\s*[Cc]apo', next_lines_text, re.MULTILINE):
        return True
    # Check for chord line pattern (like "D - Bm - G - D A" or "Am G F G" or "Em")
    if re.search(r'^[A-G][#b]?m?7?\s*[-A-G#bm7\s]*$', next_lines_text, re.MULTILINE):
        return True
    # Check for Verse/Chorus markers
    if re.search(r'^(Verse|Chorus|Intro|Bridge)[:\s]', next_lines_text, re.MULTILINE):
        return True
    # Check for section markers like [Verse]
    if re.search(r'^\[', next_lines_text, re.MULTILINE):
        return True
    
    return False

def parse_songs_database(filepath):
    """Parse the songs database file and return list of songs"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    songs = []
    current_song = None
    current_content = []
    
    # Skip the index section - find where actual songs start
    # Look for the pattern: Title - Artist followed by Capo line
    start_line = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if ' - ' in stripped and i + 1 < len(lines):
            next_line = lines[i + 1].strip()
            if next_line.lower().startswith('capo'):
                start_line = i
                break
    
    print(f"Songs content starts at line {start_line + 1}")
    
    for i in range(start_line, len(lines)):
        line = lines[i]
        stripped = line.strip()
        
        # Check if this is a new song title
        next_lines_text = '\n'.join(lines[i+1:i+6]) if i + 1 < len(lines) else ''
        
        if is_song_title_line(stripped, next_lines_text):
            # Save previous song
            if current_song:
                current_song['content'] = '\n'.join(current_content).strip()
                if current_song['content'] and len(current_song['content']) > 30:
                    current_song['capo'] = extract_capo(current_song['content'])
                    current_song['key'] = extract_key(current_song['content'])
                    songs.append(current_song)
            
            # Start new song
            title, artists, album = parse_title_line(stripped)
            current_song = {
                'id': str(uuid.uuid4()),
                'title': title or stripped,
                'artistNames': artists,
                'album': album,
                'content': '',
                'createdAt': datetime.now().isoformat() + 'Z',
                'updatedAt': datetime.now().isoformat() + 'Z',
            }
            current_content = []
        elif current_song is not None:
            current_content.append(line)
    
    # Don't forget the last song
    if current_song:
        current_song['content'] = '\n'.join(current_content).strip()
        if current_song['content'] and len(current_song['content']) > 30:
            current_song['capo'] = extract_capo(current_song['content'])
            current_song['key'] = extract_key(current_song['content'])
            songs.append(current_song)
    
    return songs

def main():
    input_file = '/Users/rajatga/Documents/CascadeProjects/windsurf-project/chordbook/sample_songs/Songs database'
    output_file = '/Users/rajatga/Documents/CascadeProjects/windsurf-project/chordbook/sample_songs/all_songs_converted.json'
    
    print(f"Parsing {input_file}...")
    songs = parse_songs_database(input_file)
    
    print(f"Found {len(songs)} songs")
    
    # Create the JSON structure
    output = {
        'version': 1,
        'exportedAt': datetime.now().isoformat() + 'Z',
        'songs': songs
    }
    
    # Write to file
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    
    print(f"Saved to {output_file}")
    
    # Print first few songs for verification
    print("\nFirst 10 songs found:")
    for song in songs[:10]:
        print(f"  - {song['title']} by {', '.join(song['artistNames']) if song['artistNames'] else 'Unknown'}")
        print(f"    Album: {song.get('album')}, Capo: {song.get('capo')}, Key: {song.get('key')}")
        print(f"    Content preview: {song['content'][:80]}...")

if __name__ == '__main__':
    main()
