#!/bin/bash

# module load ffmpeg/6.1.2
/users/PZS1154/romanodev0/ffmpeg/ffmpeg -r "$FRAMES_PER_SEC" -y -i "$INPUT_DIR/render_%04d.png" -vsync vfr -c:v libvpx-vp9 -b:v 16M -pix_fmt yuv420p "$OUTPUT_DIR/video.mp4"