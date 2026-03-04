#!/bin/bash

usage() {
  echo "Usage: $0 [INPUT_VIDEO_PATH] [OUTPUT_PATH] [QUALITY] [--max_n_ref N] [--timestep K]"
  echo
  echo "Notice: PIXEL3DMM_PATH and CAP4D_PATH environment variable must be set!"
  echo
  echo "Arguments:"
  echo "  INPUT_VIDEO_PATH   Path to the input video file or directory of images"
  echo "  OUTPUT_PATH        Path to the output directory"
  echo "  [QUALITY]          Inference quality setting [balanced|max|debug], default: balanced"
  echo
  echo "Options:"
  echo "  --max_n_ref N      Maximum number of reference frames kept after tracking conversion"
  echo "  --timestep K       FLAME timestep to bake for static export (default: 0)"
  echo "  --help             Show this help message and exit"
  exit 1
}

if [[ "$1" == "--help" ]]; then
  usage
fi

if [ -z "$PIXEL3DMM_PATH" ]; then
  echo "Error: PIXEL3DMM_PATH environment is not set. Exiting."
  exit 1
fi

if [ -z "$CAP4D_PATH" ]; then
  echo "Error: CAP4D_PATH environment is not set. Exiting."
  exit 1
fi

if [[ -z "$1" ]]; then
  echo "Error: INPUT_VIDEO_PATH is not set."
  usage
fi

if [[ -z "$2" ]]; then
  echo "Error: OUTPUT_PATH is not set."
  usage
fi

INPUT_VIDEO_PATH=$(realpath "$1")
OUTPUT_PATH=$(realpath "$2")
shift 2

QUALITY="balanced"
if [[ $# -gt 0 && "$1" != --* ]]; then
  QUALITY="$1"
  shift
fi

MAX_N_REF=""
TIMESTEP="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max_n_ref)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --max_n_ref requires a value."
        usage
      fi
      MAX_N_REF="$2"
      shift 2
      ;;
    --timestep)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --timestep requires a value."
        usage
      fi
      TIMESTEP="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      echo "Error: Unknown option '$1'."
      usage
      ;;
  esac
done

GEN_CONFIG=""
AVATAR_CONFIG=""
case "$QUALITY" in
  balanced)
    GEN_CONFIG="configs/generation/low_quality.yaml"
    AVATAR_CONFIG="configs/avatar/low_quality.yaml"
    ;;
  max)
    GEN_CONFIG="configs/generation/high_quality.yaml"
    AVATAR_CONFIG="configs/avatar/high_quality.yaml"
    ;;
  debug)
    GEN_CONFIG="configs/generation/debug.yaml"
    AVATAR_CONFIG="configs/avatar/debug.yaml"
    ;;
  *)
    echo "Error: Invalid quality '$QUALITY'. Allowed: balanced | max | debug"
    exit 1
    ;;
esac

if [ -e "$INPUT_VIDEO_PATH" ]; then
  echo "Found input at '$INPUT_VIDEO_PATH'."
else
  echo "Error: No file or directory found at '$INPUT_VIDEO_PATH'. Exiting."
  exit 1
fi

mkdir -p "$OUTPUT_PATH"

echo "Generating static avatar with:"
echo "  Input path:        $INPUT_VIDEO_PATH"
echo "  Output path:       $OUTPUT_PATH"
echo "  Quality:           $QUALITY"
echo "  Generation config: $GEN_CONFIG"
echo "  Avatar config:     $AVATAR_CONFIG"
echo "  Timestep:          $TIMESTEP"
if [[ -n "$MAX_N_REF" ]]; then
  echo "  Max refs:          $MAX_N_REF"
fi

REFERENCE_TRACKING_PATH="$OUTPUT_PATH/reference_tracking/"
TRACK_CMD=(bash scripts/track_video_pixel3dmm.sh "$INPUT_VIDEO_PATH" "$REFERENCE_TRACKING_PATH")
if [[ -n "$MAX_N_REF" ]]; then
  TRACK_CMD+=(--max_n_ref "$MAX_N_REF")
fi
"${TRACK_CMD[@]}"

IMAGE_GEN_PATH="$OUTPUT_PATH/mmdm/"
mkdir -p "$IMAGE_GEN_PATH"
python cap4d/inference/generate_images.py \
  --config_path "$GEN_CONFIG" \
  --reference_data_path "$REFERENCE_TRACKING_PATH" \
  --output_path "$IMAGE_GEN_PATH"

AVATAR_PATH="$OUTPUT_PATH/avatar/"
python gaussianavatars/train.py \
  --config_path "$AVATAR_CONFIG" \
  --source_paths "$IMAGE_GEN_PATH/reference_images/" "$IMAGE_GEN_PATH/generated_images/" \
  --model_path "$AVATAR_PATH"

python gaussianavatars/export_static_ply.py \
  --model_path "$AVATAR_PATH" \
  --source_paths "$IMAGE_GEN_PATH/reference_images/" "$IMAGE_GEN_PATH/generated_images/" \
  --output_ply "$OUTPUT_PATH/raw_static.ply" \
  --timestep "$TIMESTEP"

echo "Done. Exported static 3DGS ply at:"
echo "  $OUTPUT_PATH/raw_static.ply"
