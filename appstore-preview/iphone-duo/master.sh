#!/usr/bin/env bash
# Renders the film and masters it to App Store Connect's app preview
# specification: 886 × 1920, 30 fps, H.264 High Profile Level 4.0 at about
# 11 Mbps, and a stereo 256 kbps AAC track. The 6.9" preview ships a silent
# track, so this one does too.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p renders
npx --yes hyperframes@0.9.5 render --quality high -o renders/raw.mp4

ffmpeg -y -loglevel error \
  -i renders/raw.mp4 \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
  -map 0:v:0 -map 1:a:0 -shortest -t 30 \
  -c:v libx264 -profile:v high -level:v 4.0 -pix_fmt yuv420p -r 30 \
  -b:v 11M -maxrate 12M -bufsize 24M -preset slow \
  -c:a aac -b:a 256k -ar 48000 -ac 2 \
  -movflags +faststart \
  renders/foulee-iphone-duo-preview.mp4

ffprobe -v error -show_entries stream=codec_name,profile,level,width,height,r_frame_rate,channels,sample_rate:format=duration,size \
  -of compact renders/foulee-iphone-duo-preview.mp4
