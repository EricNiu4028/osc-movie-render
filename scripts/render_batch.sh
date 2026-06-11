#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

function frame_range() {
  (
    set +u  # allow using environment variables
    echo "$FRAME_RANGE" | perl -pe 's[.+/][]'
  )
}

module load blender/4.2

cd "$OUTPUT_DIR"

set -x

nodes=$(scontrol show hostnames $SLURM_JOB_NODELIST)

frames_start="$START_FRAME"
frames_end="$END_FRAME"

total_frames=$(( frames_end - frames_start + 1 ))
chunk=$(( (total_frames + TOTAL_NODES - 1) / TOTAL_NODES ))

for ((i=0; i<TOTAL_NODES; i++)); do
    start=$(( frames_start + chunk * i ))
    end=$(( start + chunk - 1 ))

    if (( start > frames_end )); then
        break
    fi

    if (( end > frames_end )); then
        end=$frames_end
    fi

    echo $start
    echo $end

    /bin/sbatch --exclusive -A PZS1154 -J "Render-Job-$i" --export=ALL,BLEND_FILE_PATH="$BLEND_FILE_PATH",OUTPUT_DIR="$OUTPUT_DIR",START_INST="$start",END_INST="$end" --output "$BLENDER_PATH"/jobs/%j.out -N 1 -n "$PER_CPU" "$BLENDER_PATH"/scripts/render_frames.sh
done