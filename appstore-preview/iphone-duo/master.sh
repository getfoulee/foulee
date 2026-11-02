#!/usr/bin/env bash
# Renders the film in French and in English and masters each to App Store
# Connect's app preview specification: 886 × 1920, 30 fps, H.264 High Profile
# Level 4.0 at about 11 Mbps, and a stereo 256 kbps AAC track. The 6.9"
# preview ships a silent track, so these do too.
#
#   ./master.sh          both languages
#   ./master.sh fr       French only
#   ./master.sh en       English only
set -euo pipefail
cd "$(dirname "$0")"

if [ "$#" -gt 0 ]; then
  locales=("$@")
else
  locales=(fr en)
fi
mkdir -p renders

for locale in "${locales[@]}"; do
  raw="renders/raw-$locale.mp4"
  out="renders/foulee-iphone-duo-preview-$locale.mp4"

  npx --yes hyperframes@0.9.5 render --quality high \
    --variables "{\"locale\":\"$locale\"}" --strict-variables -o "$raw"

  ffmpeg -y -loglevel error \
    -i "$raw" \
    -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
    -map 0:v:0 -map 1:a:0 -shortest -t 30 \
    -c:v libx264 -profile:v high -level:v 4.0 -pix_fmt yuv420p -r 30 \
    -b:v 11M -maxrate 12M -bufsize 24M -preset slow \
    -c:a aac -b:a 256k -ar 48000 -ac 2 \
    -movflags +faststart \
    "$out"

  echo "$out"
  ffprobe -v error -show_entries stream=codec_name,profile,level,width,height,r_frame_rate,channels,sample_rate:format=duration,size \
    -of compact "$out"
done
