#!/bin/bash

# Proxy Generator CLI v2

QUALITY="medium"
SUFFIX="_Proxy"
OUTPUT_DIR=""
CODEC="auto"
INFO_MODE=false
INPUTS=()

usage() {
    cat << EOF
Usage: prx [options] <file(s) or folder>

Options:
  -o    Output directory (default: ./proxies)
  -q    Quality: low | medium | high (default: medium)
  -s    Suffix (default: _Proxy)
  -c    Codec: auto | cpu | nvenc | amf | qsv | prores (default: auto)
  -i    Show video info & compatibility

Examples:
  prx video.mp4
  prx -i video_Proxy.mp4
  prx -q low -c nvenc ./footage
  prx -c prores -o ./proxies ./footage
EOF
    exit 1
}

show_info() {
    local file="$1"
    [[ ! -f "$file" ]] && echo "File not found: $file" && exit 1

    # Get video info
    info=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,pix_fmt,profile -show_entries format=duration,size,bit_rate -of json "$file" 2>/dev/null)
    
    codec=$(echo "$info" | grep -o '"codec_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
    width=$(echo "$info" | grep -o '"width": *[0-9]*' | cut -d: -f2 | tr -d ' ')
    height=$(echo "$info" | grep -o '"height": *[0-9]*' | cut -d: -f2 | tr -d ' ')
    fps=$(echo "$info" | grep -o '"r_frame_rate": *"[^"]*"' | cut -d'"' -f4)
    pix_fmt=$(echo "$info" | grep -o '"pix_fmt": *"[^"]*"' | cut -d'"' -f4)
    profile=$(echo "$info" | grep -o '"profile": *"[^"]*"' | cut -d'"' -f4)
    duration=$(echo "$info" | grep -o '"duration": *"[^"]*"' | cut -d'"' -f4)
    size=$(echo "$info" | grep -o '"size": *"[^"]*"' | cut -d'"' -f4)
    bitrate=$(echo "$info" | grep -o '"bit_rate": *"[^"]*"' | cut -d'"' -f4)

    # Calculate fps
    if [[ "$fps" == *"/"* ]]; then
        num=${fps%/*}; den=${fps#*/}
        fps_val=$(echo "scale=2; $num / $den" | bc)
    else
        fps_val=$fps
    fi

    # Format size
    if [[ -n "$size" ]]; then
        size_mb=$(echo "scale=2; $size / 1048576" | bc)
    else
        size_mb="N/A"
    fi

    # Format duration
    if [[ -n "$duration" ]]; then
        dur_int=${duration%.*}
        dur_fmt=$(printf "%02d:%02d:%02d" $((dur_int/3600)) $((dur_int%3600/60)) $((dur_int%60)))
    else
        dur_fmt="N/A"
    fi

    # Format bitrate
    if [[ -n "$bitrate" ]]; then
        bitrate_mbps=$(echo "scale=2; $bitrate / 1000000" | bc)
    else
        bitrate_mbps="N/A"
    fi

    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      VIDEO INFORMATION                       ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║  %-60s ║\n" "File: $(basename "$file")"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║  %-20s %-39s ║\n" "Codec:" "$codec ($profile)"
    printf "║  %-20s %-39s ║\n" "Resolution:" "${width}x${height}"
    printf "║  %-20s %-39s ║\n" "Frame Rate:" "${fps_val} fps"
    printf "║  %-20s %-39s ║\n" "Pixel Format:" "$pix_fmt"
    printf "║  %-20s %-39s ║\n" "Duration:" "$dur_fmt"
    printf "║  %-20s %-39s ║\n" "File Size:" "${size_mb} MB"
    printf "║  %-20s %-39s ║\n" "Bitrate:" "${bitrate_mbps} Mbps"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║                    SOFTWARE COMPATIBILITY                    ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    
    # Desktop editors
    echo "║  Desktop:                                                    ║"
    case $codec in
        h264)
            printf "║    %-56s ║\n" "✓ DaVinci Resolve"
            printf "║    %-56s ║\n" "✓ Premiere Pro"
            printf "║    %-56s ║\n" "✓ Final Cut Pro"
            printf "║    %-56s ║\n" "✓ After Effects"
            printf "║    %-56s ║\n" "✓ Kdenlive / Shotcut"
            ;;
        prores)
            printf "║    %-56s ║\n" "✓ DaVinci Resolve (recommended)"
            printf "║    %-56s ║\n" "✓ Premiere Pro (recommended)"
            printf "║    %-56s ║\n" "✓ Final Cut Pro (native)"
            printf "║    %-56s ║\n" "✓ After Effects"
            printf "║    %-56s ║\n" "△ Kdenlive (needs codec)"
            ;;
        hevc|h265)
            printf "║    %-56s ║\n" "✓ DaVinci Resolve"
            printf "║    %-56s ║\n" "✓ Premiere Pro (CC 2018+)"
            printf "║    %-56s ║\n" "✓ Final Cut Pro"
            printf "║    %-56s ║\n" "△ After Effects (limited)"
            printf "║    %-56s ║\n" "△ Kdenlive (depends on build)"
            ;;
        *)
            printf "║    %-56s ║\n" "? Unknown codec compatibility"
            ;;
    esac
    
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  ✓ Full support  △ Partial support  ✗ Not supported         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

detect_gpu_encoder() {
    for enc in h264_nvenc h264_amf h264_qsv; do
        if ffmpeg -f lavfi -i nullsrc=s=256x256:d=1 -c:v $enc -f null - 2>/dev/null; then
            echo "$enc"; return
        fi
    done
    echo "libx264"
}

get_duration() {
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}

format_time() {
    local s=$1
    printf "%02d:%02d:%02d" $((s/3600)) $((s%3600/60)) $((s%60))
}

while getopts "o:q:s:c:ih" opt; do
    case $opt in
        o) OUTPUT_DIR="$OPTARG" ;;
        q) QUALITY="$OPTARG" ;;
        s) SUFFIX="$OPTARG" ;;
        c) CODEC="$OPTARG" ;;
        i) INFO_MODE=true ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

[[ $# -eq 0 ]] && usage

# Info mode
if $INFO_MODE; then
    show_info "$1"
    exit 0
fi

# Set encoder
case $CODEC in
    auto)   ENCODER=$(detect_gpu_encoder) ;;
    cpu)    ENCODER="libx264" ;;
    nvenc)  ENCODER="h264_nvenc" ;;
    amf)    ENCODER="h264_amf" ;;
    qsv)    ENCODER="h264_qsv" ;;
    prores) ENCODER="prores_ks" ;;
    *) echo "Invalid codec" && exit 1 ;;
esac

# Quality settings
case $QUALITY in
    low)    SCALE="scale=-2:360"; CRF=28; PRORES_PROFILE=0 ;;
    medium) SCALE="scale=-2:720"; CRF=23; PRORES_PROFILE=1 ;;
    high)   SCALE="scale=-2:1080"; CRF=18; PRORES_PROFILE=2 ;;
    *) echo "Invalid quality. Use: low, medium, high" && exit 1 ;;
esac

# Encoder-specific options
case $ENCODER in
    libx264)     ENC_OPTS="-preset fast -crf $CRF" ;;
    h264_nvenc)  ENC_OPTS="-preset p4 -cq $CRF" ;;
    h264_amf)    ENC_OPTS="-quality balanced -qp_i $CRF -qp_p $CRF" ;;
    h264_qsv)    ENC_OPTS="-preset medium -global_quality $CRF" ;;
    prores_ks)   ENC_OPTS="-profile:v $PRORES_PROFILE -vendor apl0"; SCALE="scale=-2:720" ;;
esac

# Collect files
for input in "$@"; do
    if [[ -d "$input" ]]; then
        shopt -s nullglob nocaseglob
        for f in "$input"/*.{mp4,mov,avi,mkv,mxf,webm}; do
            INPUTS+=("$f")
        done
        shopt -u nullglob nocaseglob
    elif [[ -f "$input" ]]; then
        INPUTS+=("$input")
    else
        echo "Warning: '$input' not found, skipping"
    fi
done

total=${#INPUTS[@]}
[[ $total -eq 0 ]] && echo "No video files found" && exit 1

[[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="./proxies"
mkdir -p "$OUTPUT_DIR"

EXT="mp4"
[[ $ENCODER == "prores_ks" ]] && EXT="mov"

echo "Encoder: $ENCODER | Quality: $QUALITY | Files: $total"
echo ""

total_duration=0
for file in "${INPUTS[@]}"; do
    dur=$(get_duration "$file")
    total_duration=$(echo "$total_duration + ${dur:-0}" | bc)
done

processed_duration=0
start_time=$(date +%s)
count=0

for file in "${INPUTS[@]}"; do
    ((count++))
    filename=$(basename "$file")
    name="${filename%.*}"
    output="$OUTPUT_DIR/${name}${SUFFIX}.$EXT"
    file_duration=$(get_duration "$file")
    
    # Progress bar
    pct=$((count * 100 / total))
    filled=$((pct / 2))
    bar=$(printf "%${filled}s" | tr ' ' '█')$(printf "%$((50-filled))s" | tr ' ' '░')
    
    # ETA calculation
    elapsed=$(($(date +%s) - start_time))
    if [[ $count -gt 1 && $elapsed -gt 0 ]]; then
        speed=$(echo "$processed_duration / $elapsed" | bc -l 2>/dev/null)
        remaining=$(echo "($total_duration - $processed_duration) / $speed" | bc 2>/dev/null)
        eta=$(format_time ${remaining%.*})
    else
        eta="--:--:--"
    fi
    
    printf "\r[%s] %d%% (%d/%d) ETA: %s | %s" "$bar" "$pct" "$count" "$total" "$eta" "$filename"
    
    if [[ $ENCODER == "prores_ks" ]]; then
        ffmpeg -i "$file" -vf "$SCALE" -c:v $ENCODER $ENC_OPTS -c:a pcm_s16le -y "$output" 2>/dev/null
    else
        ffmpeg -i "$file" -vf "$SCALE" -c:v $ENCODER $ENC_OPTS -c:a aac -b:a 128k -y "$output" 2>/dev/null
    fi
    
    processed_duration=$(echo "$processed_duration + ${file_duration:-0}" | bc)
done

elapsed=$(($(date +%s) - start_time))
printf "\n\nDone! %d files in %s → %s\n" "$total" "$(format_time $elapsed)" "$OUTPUT_DIR"
