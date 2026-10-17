#!/bin/zsh
# Creates a sample media folder for manual testing. Usage: scripts/make_fixtures.sh [output-dir]
set -e
cd "$(dirname "$0")/.."
OUT="${1:-$PWD/TestFixtures/Media}"
mkdir -p "$OUT/Music/Albums" "$OUT/Other"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift scripts/MakeFixtures.swift "$OUT"
# Audio via built-in speech + afconvert.
say -o "$OUT/Music/Morning Song.aiff" "This is a test song for E-LARA. La la la la la. Good morning."
afconvert -f m4af -d aac "$OUT/Music/Morning Song.aiff" "$OUT/Music/Albums/Evening Tune.m4a"
afconvert -f WAVE -d LEI16 "$OUT/Music/Morning Song.aiff" "$OUT/Music/Albums/Rain Sounds.wav"
afconvert -f caff -d alac "$OUT/Music/Morning Song.aiff" "$OUT/Music/Lossless Track.caf"
# Non-media and broken files that must not crash anything.
echo "not media" > "$OUT/Other/readme.txt"
echo "%PDF-1.4 fake" > "$OUT/Other/document.pdf"
echo "this is not really a jpeg" > "$OUT/Other/Broken Image.jpg"
echo "this is not really an mp3" > "$OUT/Other/Corrupt Song.mp3"
echo "Fixtures written to $OUT"
