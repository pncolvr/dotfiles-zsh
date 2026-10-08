#!/usr/bin/env bash
# Choose video encoding settings interactively, or supply them as flags.
set -uo pipefail

INPUT="" TEMP_DIR="" ENCODING_PID=""
DIRECT=false
CODEC="" HEIGHT=source FPS=30 QUALITY="" AUDIO_BITRATE="" ENCODER="" PRESET=""
AUDIO=aac VOLUME=1 THREADS=2 PIXEL_FORMAT=yuv420p HARDWARE=auto

usage() {
    cat <<'HELP'
Usage: smaller.sh FILE [encoding options]

Without flags, choose codec, resolution, frame rate, quality and audio,
review the settings, then convert. Encoding flags run directly.

  --codec h264|hevc|av1       Video codec (default: h264)
  --height PIXELS|source     Maximum height (default: source)
  --fps NUMBER|source        Maximum fps (default: 30; source keeps timing)
  --quality NUMBER           CRF/CQ (default depends on codec and encoder)
  --audio-bitrate RATE       AAC bitrate, e.g. 128k (default: 128k/64k)
  --audio aac|copy|none       Encode, copy or remove audio (default: aac)
  --volume NUMBER            Audio volume multiplier (default: 1; AAC only)
  --hardware auto|nvidia|cpu Encoder selection (default: auto)
  --encoder NAME             Explicit encoder, e.g. libx264 or hevc_nvenc
  --preset NAME              Encoder preset (default: p5/veryfast/10)
  --threads NUMBER           Encoder threads (default: 2)
  --pixel-format NAME        Pixel format (default: yuv420p)
  -h, --help                 Show this help

The original is kept. Output is MP4 beside the input, with codec, resolution
and fps in the filename. Existing outputs are skipped. There are no sample
encodes or pre-conversion estimates.
HELP
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
cleanup() {
    if [[ -n "$ENCODING_PID" ]]; then
        kill "$ENCODING_PID" 2>/dev/null || true
        wait "$ENCODING_PID" 2>/dev/null || true
    fi
    if [[ -n "$TEMP_DIR" ]]; then
        rm -f -- "$TEMP_DIR/output.mp4" "$TEMP_DIR/output.progress" "$TEMP_DIR/encode.log"
        rmdir -- "$TEMP_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'printf "\nCancelled.\n"; exit 130' INT TERM

ask() {
    local prompt=$1 default=${2:-}
    printf '%s' "$prompt"
    [[ -z "$default" ]] || printf ' [%s]' "$default"
    printf ': '
    if ! IFS= read -r REPLY; then printf '\nCancelled.\n'; exit 130; fi
    [[ "$REPLY" != q && "$REPLY" != Q ]] || exit 130
    REPLY=${REPLY:-$default}
}

choose() {
    local title=$1 default=$2 index=1 label count
    shift 2; count=$#
    printf '\n%s\n' "$title"
    for label in "$@"; do printf '  %d) %s\n' "$index" "$label"; ((index+=1)); done
    if (( count == 1 )); then REPLY=1; return; fi
    while true; do
        ask 'Choose' "$default"
        if [[ "$REPLY" =~ ^[1-9][0-9]?$ ]] && (( REPLY <= count )); then return; fi
        printf 'Enter a number from 1 to %s, or q to cancel.\n' "$count"
    done
}

number() {
    local prompt=$1 default=$2 minimum=$3 maximum=$4 integer=${5:-false}
    while true; do
        ask "$prompt" "$default"
        if "$integer" && [[ ! "$REPLY" =~ ^[0-9]+$ ]]; then
            printf 'Enter a whole number from %s to %s.\n' "$minimum" "$maximum"
            continue
        fi
        if [[ "$REPLY" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v value="$REPLY" -v low="$minimum" -v high="$maximum" 'BEGIN {exit !(value>=low && value<=high)}'; then
            if "$integer"; then REPLY=$(awk -v value="$REPLY" 'BEGIN {printf "%d",value}'); fi
            return
        fi
        printf 'Enter a number from %s to %s.\n' "$minimum" "$maximum"
    done
}

human_size() {
    awk -v size="$1" 'BEGIN {split("B KiB MiB GiB TiB",units); i=1; while(size>=1024 && i<5) {size/=1024; i++} printf "%.1f %s",size,units[i]}'
}

while (( $# )); do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --codec|--height|--fps|--quality|--audio-bitrate|--audio|--volume|--hardware|--encoder|--preset|--threads|--pixel-format)
            (( $# >= 2 )) && [[ "$2" != --* && -n "$2" ]] || fail "$1 needs a value"
            case "$1" in
                --codec) CODEC=$2 ;; --height) HEIGHT=$2 ;; --fps) FPS=$2 ;;
                --quality) QUALITY=$2 ;; --audio-bitrate) AUDIO_BITRATE=$2 ;; --audio) AUDIO=$2 ;;
                --volume) VOLUME=$2 ;; --hardware) HARDWARE=$2 ;; --encoder) ENCODER=$2 ;;
                --preset) PRESET=$2 ;; --threads) THREADS=$2 ;; --pixel-format) PIXEL_FORMAT=$2 ;;
            esac
            DIRECT=true; shift 2 ;;
        --) shift; (( $# == 1 )) && [[ -z "$INPUT" ]] || fail 'Provide one video file'; INPUT=$1; shift ;;
        -*) fail "Unknown option: $1" ;;
        *) [[ -z "$INPUT" ]] || fail 'Provide one video file'; INPUT=$1; shift ;;
    esac
done
[[ -n "$INPUT" ]] || { usage >&2; exit 1; }
for dependency in ffmpeg ffprobe awk timeout realpath stat mktemp mv; do
    command -v "$dependency" >/dev/null || fail "Required command is missing: $dependency"
done
if [[ -n "$ENCODER" ]]; then
    case "$ENCODER" in
        h264_nvenc|libx264) encoder_codec=h264 ;;
        hevc_nvenc|libx265) encoder_codec=hevc ;;
        av1_nvenc|libsvtav1) encoder_codec=av1 ;;
        *) fail 'Unsupported encoder' ;;
    esac
    [[ -z "$CODEC" || "$CODEC" == "$encoder_codec" ]] || fail 'Codec and encoder do not match'
    CODEC=$encoder_codec
fi
CODEC=${CODEC:-h264}
case "$CODEC" in h264|hevc|av1) ;; *) fail 'Codec must be h264, hevc or av1' ;; esac
case "$HARDWARE" in auto|nvidia|cpu) ;; *) fail 'Hardware must be auto, nvidia or cpu' ;; esac
case "$AUDIO" in aac|copy|none) ;; *) fail 'Audio must be aac, copy or none' ;; esac
[[ "$VOLUME" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v value="$VOLUME" 'BEGIN {exit !(value>=0 && value<=10)}' || fail 'Volume must be between 0 and 10'
if [[ "$AUDIO" != aac ]] && awk -v volume="$VOLUME" 'BEGIN {exit !(volume!=1)}'; then fail 'Volume requires AAC audio encoding'; fi
[[ "$THREADS" =~ ^[0-9]{1,3}$ ]] && (( 10#$THREADS >= 1 && 10#$THREADS <= 256 )) || fail 'Threads must be between 1 and 256'
THREADS=$((10#$THREADS))
[[ -z "$PRESET" || "$PRESET" =~ ^[a-zA-Z0-9_-]+$ ]] || fail 'Invalid preset'
[[ "$PIXEL_FORMAT" =~ ^[a-zA-Z0-9_]+$ ]] || fail 'Invalid pixel format'
[[ -z "$AUDIO_BITRATE" || "$AUDIO_BITRATE" =~ ^[1-9][0-9]*[kM]?$ ]] || fail 'Invalid audio bitrate (example: 128k)'

case "$INPUT" in '~/'*) INPUT="$HOME/${INPUT:2}" ;; esac
[[ -f "$INPUT" ]] || fail "Provide one existing video file: $INPUT"
INPUT=$(realpath -e -- "$INPUT") || exit 1
metadata=$(ffprobe -v error -select_streams V:0 \
    -show_entries 'stream=width,height,avg_frame_rate:stream_side_data=rotation:format=duration' \
    -of default=noprint_wrappers=1 "$INPUT") || fail 'Cannot read the input video'
video_width=0 video_height=0 video_fps=0 video_duration=0 rotation=0
while IFS='=' read -r key value; do
    case "$key" in
        width) video_width=$value ;; height) video_height=$value ;;
        avg_frame_rate) video_fps=$(awk -v rate="$value" 'BEGIN {split(rate,a,"/"); print (a[2]>0 ? a[1]/a[2] : 0)}') ;;
        duration) [[ "$value" == N/A ]] || video_duration=$value ;;
        rotation) rotation=$value ;;
    esac
done <<< "$metadata"
(( video_width >= 2 && video_height >= 2 )) || fail 'The input has no usable video stream'
if [[ "$rotation" == 90 || "$rotation" == -90 || "$rotation" == 270 || "$rotation" == -270 ]]; then
    value=$video_width; video_width=$video_height; video_height=$value
fi
video_size=$(stat -c %s -- "$INPUT") || exit 1
printf '\nSmaller — encode a video\nInput: %s\n  %s×%s, %s fps, %ss, %s\n' \
    "${INPUT##*/}" "$video_width" "$video_height" "$video_fps" "$video_duration" "$(human_size "$video_size")"

if ! "$DIRECT"; then
    printf 'Enter accepts defaults; q or Ctrl+C cancels.\n'
    choose 'Codec' 1 'H.264 — broad playback compatibility' 'H.265 (HEVC)' 'AV1'
    codecs=(h264 hevc av1); CODEC=${codecs[$((REPLY-1))]}
    source_height=$((video_height / 2 * 2))
    heights=("$source_height"); labels=("Keep source height (${source_height}p)"); default=1
    for height in 1080 720; do
        if (( height < source_height )); then
            heights+=("$height"); labels+=("${height}p")
            [[ "$height" != 1080 ]] || default=${#heights[@]}
        fi
    done
    choose 'Resolution' "$default" "${labels[@]}"; HEIGHT=${heights[$((REPLY-1))]}
    frame_rates=(source); labels=("Keep source timing (${video_fps} fps)"); default=1
    for fps in 60 30 15; do
        if awk -v source="$video_fps" -v cap="$fps" 'BEGIN {exit !(source>cap)}'; then
            frame_rates+=("$fps"); labels+=("${fps} fps")
            [[ "$fps" != 30 ]] || default=${#frame_rates[@]}
        fi
    done
    choose 'Frame rate' "$default" "${labels[@]}"; FPS=${frame_rates[$((REPLY-1))]}
fi
case "$HEIGHT" in source) HEIGHT=$video_height ;; esac
[[ "$HEIGHT" =~ ^[0-9]{1,5}$ ]] && (( 10#$HEIGHT >= 2 && 10#$HEIGHT <= 32768 )) || fail 'Height must be source or an integer from 2 to 32768'
HEIGHT=$((10#$HEIGHT)); (( HEIGHT <= video_height )) || HEIGHT=$video_height
HEIGHT=$((HEIGHT / 2 * 2))
case "$FPS" in source) FPS=0 ;; esac
[[ "$FPS" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v fps="$FPS" 'BEGIN {exit !(fps>=0 && fps<=1000)}' || fail 'FPS must be source or a number from 0 to 1000'

printf '\nChecking encoder...\n'
encoder_list=$(ffmpeg -hide_banner -encoders 2>/dev/null) || fail 'Cannot list FFmpeg encoders'
gpu=${CODEC}_nvenc
case "$CODEC" in h264) cpu=libx264 ;; hevc) cpu=libx265 ;; av1) cpu=libsvtav1 ;; esac
if [[ "$HARDWARE" != cpu && ( -z "$ENCODER" || "$ENCODER" == "$gpu" ) && "$encoder_list" == *" $gpu "* ]] && \
    timeout --kill-after=0.2s 1s ffmpeg -hide_banner -loglevel error -nostdin -f lavfi -i color=s=256x256:r=30 \
    -frames:v 1 -c:v "$gpu" -f null - >/dev/null 2>&1; then ENCODER=$gpu
elif [[ "$HARDWARE" != nvidia && ( -z "$ENCODER" || "$ENCODER" == "$cpu" ) && "$encoder_list" == *" $cpu "* ]]; then ENCODER=$cpu
else fail "No usable encoder for $CODEC with the requested hardware"; fi
case "$CODEC" in
    h264) base_quality=23; [[ "$ENCODER" != *_nvenc ]] || base_quality=19; default_audio=128k ;;
    hevc) base_quality=28; [[ "$ENCODER" != *_nvenc ]] || base_quality=34; default_audio=64k ;;
    av1) base_quality=35; default_audio=64k ;;
esac
max_quality=51; [[ "$ENCODER" != libsvtav1 ]] || max_quality=63
QUALITY=${QUALITY:-$base_quality} AUDIO_BITRATE=${AUDIO_BITRATE:-$default_audio}
if [[ -z "$PRESET" ]]; then
    PRESET=veryfast
    if [[ "$ENCODER" == *_nvenc ]]; then PRESET=p5; elif [[ "$CODEC" == av1 ]]; then PRESET=10; fi
fi
if ! "$DIRECT"; then
    choose 'Quality — lower numbers retain more detail and usually produce larger files' 1 \
        "Balanced ($base_quality)" "Higher quality ($((base_quality-5)))" "Smaller file ($((base_quality+5)))" 'Custom value'
    case "$REPLY" in
        1) QUALITY=$base_quality ;; 2) QUALITY=$((base_quality-5)) ;; 3) QUALITY=$((base_quality+5)) ;;
        4) number 'Quality' "$base_quality" 0 "$max_quality" true; QUALITY=$REPLY ;;
    esac
    default=1; [[ "$default_audio" != 64k ]] || default=2
    choose 'Audio' "$default" 'AAC 128k' 'AAC 64k' 'AAC 192k' 'Copy original audio' 'Remove audio'
    case "$REPLY" in
        1) AUDIO_BITRATE=128k ;; 2) AUDIO_BITRATE=64k ;; 3) AUDIO_BITRATE=192k ;; 4) AUDIO=copy ;; 5) AUDIO=none ;;
    esac
    if [[ "$AUDIO" == aac ]]; then number 'Volume multiplier (1 = unchanged, 2 = double)' 1 0 10; VOLUME=$REPLY; fi
fi
[[ "$QUALITY" =~ ^[0-9]{1,2}$ ]] && (( 10#$QUALITY <= max_quality )) || fail "Quality must be between 0 and $max_quality"
QUALITY=$((10#$QUALITY))

output_fps=$(awk -v source="$video_fps" -v cap="$FPS" 'BEGIN {fps=(cap==0 || (source>0 && source<cap) ? source : cap); if(fps<=0) {print "source"; exit} label=sprintf("%.3f",fps); sub(/0+$/, "", label); sub(/\.$/, "", label); print label}')
name=${INPUT##*/}
OUTPUT="${INPUT%/*}/${name%.*}_smaller_${CODEC}_${HEIGHT}p_${output_fps}fps.mp4"
printf '\nSettings: %s / %s, %sp, %sfps, quality %s, preset %s\n' "$CODEC" "$ENCODER" "$HEIGHT" "$output_fps" "$QUALITY" "$PRESET"
if [[ "$AUDIO" == aac ]]; then printf 'Audio: AAC %s, volume %s×\n' "$AUDIO_BITRATE" "$VOLUME"
else printf 'Audio: %s\n' "$AUDIO"; fi
printf 'Output: %s\nRepeat command:' "$OUTPUT"
printf ' %q' smaller "$INPUT" --codec "$CODEC" --height "$HEIGHT" --fps "$FPS" --quality "$QUALITY" \
    --encoder "$ENCODER" --preset "$PRESET" --audio "$AUDIO" --audio-bitrate "$AUDIO_BITRATE" \
    --volume "$VOLUME" --threads "$THREADS" --pixel-format "$PIXEL_FORMAT"
printf '\n'
if ! "$DIRECT"; then
    choose 'Start encoding?' 1 Yes Cancel
    if [[ "$REPLY" == 2 ]]; then printf 'Cancelled.\n'; exit 0; fi
fi
if [[ -e "$OUTPUT" || -L "$OUTPUT" ]]; then printf 'Skipped: output already exists.\n'; exit 0; fi

filter="scale=-2:trunc(min(ih\\,$HEIGHT)/2)*2"
if awk -v source="$video_fps" -v cap="$FPS" 'BEGIN {exit !(cap>0 && (source==0 || source>cap))}'; then filter+=",fps=$FPS"; fi
ARGS=(-map 0:V:0 -vf "$filter" -c:v "$ENCODER" -pix_fmt "$PIXEL_FORMAT" -threads "$THREADS" -preset "$PRESET")
if [[ "$ENCODER" == *_nvenc ]]; then ARGS+=(-rc:v vbr -cq:v "$QUALITY" -b:v 0)
else
    ARGS+=(-crf "$QUALITY")
    case "$CODEC" in
        av1) ARGS+=(-svtav1-params "lp=$THREADS") ;;
        hevc) ARGS+=(-x265-params "pools=$THREADS:frame-threads=1:log-level=error") ;;
    esac
fi
[[ "$CODEC" != hevc ]] || ARGS+=(-tag:v hvc1)
case "$AUDIO" in
    aac) ARGS+=(-map '0:a?' -c:a aac -b:a "$AUDIO_BITRATE"); [[ "$VOLUME" == 1 ]] || ARGS+=(-af "volume=$VOLUME") ;;
    copy) ARGS+=(-map '0:a?' -c:a copy) ;;
    none) ARGS+=(-an) ;;
esac
ARGS+=(-movflags +faststart)
TEMP_DIR=$(mktemp -d -- "${INPUT%/*}/.smaller-XXXXXX") || fail 'Cannot create temporary output'
started=${EPOCHREALTIME:-$SECONDS}
ffmpeg -hide_banner -loglevel warning -nostats -nostdin -stats_period 1 \
    -progress "$TEMP_DIR/output.progress" -i "$INPUT" "${ARGS[@]}" -n "$TEMP_DIR/output.mp4" \
    > /dev/null 2> "$TEMP_DIR/encode.log" &
ENCODING_PID=$!
last_update=-1
while kill -0 "$ENCODING_PID" 2>/dev/null; do
    if [[ "$last_update" != "$SECONDS" ]]; then
        progress_file="$TEMP_DIR/output.progress"; [[ -f "$progress_file" ]] || progress_file=/dev/null
        [[ ! -t 1 ]] || printf '\r'
        awk -F= -v duration="$video_duration" -v started="$started" -v now="${EPOCHREALTIME:-$SECONDS}" '
            $1=="out_time_us" && $2 ~ /^-?[0-9]+$/ {media=$2/1000000}
            END {
                elapsed=now-started; percent=(duration>0 ? int(media/duration*100) : 0)
                if(percent<0) percent=0; if(percent>99) percent=99
                remaining=(media>0 && duration>media ? sprintf("~%.0fs",elapsed*(duration-media)/media) : "—")
                printf "Encoding %3d%% | elapsed %.0fs | remaining %-12s",percent,elapsed,remaining
            }' "$progress_file"
        [[ -t 1 ]] || printf '\n'
        last_update=$SECONDS
    fi
    sleep 0.1
done
[[ ! -t 1 ]] || printf '\n'
status=0; wait "$ENCODING_PID" || status=$?
ENCODING_PID=""
[[ ! -s "$TEMP_DIR/encode.log" ]] || cat "$TEMP_DIR/encode.log" >&2
(( status == 0 )) || fail 'Encoding failed'
mv -nT -- "$TEMP_DIR/output.mp4" "$OUTPUT" || fail 'Cannot save output'
if [[ -e "$TEMP_DIR/output.mp4" ]]; then printf 'Skipped: output appeared during encoding.\n'; exit 0; fi
printf '\nEncoding complete.\nOutput file size: %s (original: %s).\n%s\n' \
    "$(human_size "$(stat -c %s -- "$OUTPUT")")" "$(human_size "$video_size")" "$OUTPUT"
