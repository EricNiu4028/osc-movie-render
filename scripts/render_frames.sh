#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

function frame_range() {
  (
    set +u  # allow using environment variables
    echo "$FRAME_RANGE" | perl -pe 's[.+/][]'
  )
}

# Use LMod to load Blender into our PATH
module load blender/4.2

# Change directory to where our .blend file is
cd "$OUTPUT_DIR"

set -x

# Call blender on our blend file.
#   -b which blend to work on
#   -F sets the file format
#   -o sets the output directory; defaults to /tmp
#   -x allows blender to set the file extension
#   -t 0 allows blender to use as many threads as there are processors
#   -a render all scenes in the blend
/apps/blender/4.2/bin/blender \
  -b "$BLEND_FILE_PATH" \
  -F PNG \
  -o "$OUTPUT_DIR/render_" \
  -x 1 \
  -t 0 \
  -E CYCLES \
  -y \
  -s "$START_INST" \
  -e "$END_INST" \
  -a