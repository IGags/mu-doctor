#!/usr/bin/bash
set -e

command -v ffmpeg > /dev/null
command -v ffprobe > /dev/null
command -v awk > /dev/null

if [ $# -eq 0 ]; then
  echo "Please write a correct path to ur music as 1 arg"
  exit 1
fi

BASE_DIR="$1"
BASE_DIR="${BASE_DIR%/}/"

declare -a FILES=()
readarray -d '' FILES < <(find "$BASE_DIR" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.wav" \) -print0)

TOTAL_CT="${#FILES[@]}"
printf "Found %s tracks\n" "$TOTAL_CT"

set +e
declare -a ERORRS=()

COMPLETE=0
printf "\r$COMPLETE/$TOTAL_CT"
for file in "${FILES[@]}"; do
  OUTPUT=$(ffmpeg -xerror -i "$file" -f null - 2>&1)
  OUT_CODE=$?

  if (( OUT_CODE != 0 )); then
    ERORRS+=("$file")
    COMPLETE=$((COMPLETE + 1))
    printf "\r$COMPLETE/$TOTAL_CT errors ${#ERORRS[@]}"
    continue
  fi
  
  META_LEN=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 "$file" | cut -d= -f2)
  ACTUAL_LEN=$(echo "$OUTPUT" | grep -o "time=[0-9:.]*" | tail -n 1 | cut -d= -f2 | awk -F: '{print ($1*3600)+($2*60)+$3}')

  DIFFERENCE=$(awk -v n1="$META_LEN" -v n2="$ACTUAL_LEN" 'BEGIN { diff = n1 - n2; abs = (diff < 0) ? -diff : diff; print (abs <= 0.5) ? "true" : "false" }')
  if ! "$DIFFERENCE"; then
    ERORRS+=("$file")
  fi

  COMPLETE=$((COMPLETE + 1))
  printf "\r$COMPLETE/$TOTAL_CT errors ${#ERORRS[@]}"
done
echo ""
printf "%s\n" "${ERORRS[@]}"
