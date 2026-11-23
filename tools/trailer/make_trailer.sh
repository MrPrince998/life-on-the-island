#!/bin/sh
# Films the trailer in the real game and encodes it to exports/LifeOnTheIsland_Trailer.mp4.
# Usage: tools/trailer/make_trailer.sh [path-to-ffmpeg] [path-to-godot]
# Needs a real window (not --headless) and ffmpeg. Frames go to a temporary folder
# (about 5 GB at 1080p) that is deleted afterwards.
FFMPEG="${1:-ffmpeg}"
GODOT="${2:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/../.." || exit 1
WORK="$(mktemp -d)"
OUT="exports/LifeOnTheIsland_Trailer.mp4"
mkdir -p exports
echo "Filming the trailer (this takes a few minutes)..."
"$GODOT" --path . --resolution 1920x1080 --fixed-fps 30 --disable-vsync \
	--write-movie "$WORK/frame.png" res://tools/trailer/trailer.tscn || exit 1
echo "Encoding $OUT..."
# The first 10 s are the hidden warm-up (PREROLL_FRAMES in trailer.gd): cut them.
"$FFMPEG" -y -loglevel error -framerate 30 -ss 10 -i "$WORK/frame%08d.png" -ss 10 -i "$WORK/frame.wav" \
	-c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -c:a aac -b:a 192k \
	-movflags +faststart -shortest "$OUT" || exit 1
rm -rf "$WORK"
# Keep the window visible while filming: if it was covered, some frames can come out
# black. Check: only the short dips between shots (under a second) may be black.
LONG_BLACK=$("$FFMPEG" -i "$OUT" -vf "blackdetect=d=1.2:pix_th=0.08" -an -f null - 2>&1 | grep -c black_start)
if [ "$LONG_BLACK" -gt 0 ]; then
	echo "WARNING: $OUT has long black stretches; film it again with the window in view."
	exit 2
fi
echo "Done: $OUT"
