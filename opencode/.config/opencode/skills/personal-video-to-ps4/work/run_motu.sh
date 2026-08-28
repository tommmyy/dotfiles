#!/bin/bash
SRC="/Users/tommmyy/Downloads/Masters.of.the.Universe.2026.1080p.AMZN.WEB-DL.DDP5.1.H264-TreZzoR/Masters.of.the.Universe.2026.1080p.AMZN.WEB-DL.DDP5.1.H264-TreZzoR.mkv"
OUT="/Users/tommmyy/Downloads/Masters_of_the_Universe_2026_PS4.mp4"
MOVIES="/Volumes/tommmyy/Movies"
DEST="$MOVIES/Masters_of_the_Universe_2026_PS4.mp4"
J="/Users/tommmyy/.config/opencode/skills/personal-video-to-ps4/work/journal.jsonl"

jr() { printf '%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$1" "$DEST" "$2" >> "$J"; }

jr START "video=copy audio=3x eac3->ac3 640k subs=5x subrip->mov_text"

ffmpeg -y -i "$SRC" \
  -map 0:v:0 \
  -map 0:a:0 -map 0:a:1 -map 0:a:2 \
  -map 0:s:0 -map 0:s:1 -map 0:s:2 -map 0:s:3 -map 0:s:4 \
  -c:v copy -tag:v avc1 \
  -c:a ac3 -b:a 640k \
  -c:s mov_text \
  -disposition:a 0 -disposition:a:0 default \
  -disposition:s 0 \
  -metadata:s:a:0 language=ces -metadata:s:a:0 title="Czech 5.1" \
  -metadata:s:a:1 language=slk -metadata:s:a:1 title="Slovak 5.1" \
  -metadata:s:a:2 language=eng -metadata:s:a:2 title="English 5.1" \
  -metadata:s:s:0 language=ces -metadata:s:s:0 title="Czech Forced" \
  -metadata:s:s:1 language=slk -metadata:s:s:1 title="Slovak Forced" \
  -metadata:s:s:2 language=ces -metadata:s:s:2 title="Czech Full" \
  -metadata:s:s:3 language=slk -metadata:s:s:3 title="Slovak Full" \
  -metadata:s:s:4 language=eng -metadata:s:s:4 title="English SDH" \
  -metadata title="Masters of the Universe" -metadata year="2026" \
  -metadata date="2026" -metadata genre="Action, Adventure, Fantasy, Sci-Fi" \
  -fflags +genpts -avoid_negative_ts make_zero -movflags +faststart "$OUT" \
  || { jr FAIL "ffmpeg error"; exit 1; }

vd=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$OUT" | tr -d ',\n')
vp=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt   -of csv=p=0 "$OUT" | tr -d ',\n')
ad=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$OUT" | tr -d ',\n')
st=$(ffprobe -v error -select_streams a:0 -show_entries stream=start_time -of csv=p=0 "$OUT" | tr -d ',\n')
na=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$OUT" | wc -l | tr -d ' ')
ns=$(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$OUT" | wc -l | tr -d ' ')
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" | tr -d ',\n')
jr VERIFY-LOCAL "v=$vd/$vp a=$ad start=$st na=$na ns=$ns dur=$dur"

if [ "$vd" != h264 ] || [ "$vp" != yuv420p ] || [ "$ad" != ac3 ] || [ "$na" != 3 ] || [ "$ns" != 5 ]; then
  jr FAIL "local verify mismatch"; exit 1
fi
nz=$(awk -v s="$st" 'BEGIN{ print (s+0 > 0.001) ? "1" : "0" }')
if [ "$nz" = 1 ]; then jr FAIL "nonzero a:0 start_time=$st -> needs bake-silence"; exit 1; fi

cp -- "$OUT" "$DEST" || { jr FAIL "cp failed"; exit 1; }

dvd=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$DEST" | tr -d ',\n')
ddur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$DEST" | tr -d ',\n')
jr VERIFY-DEST "v=$dvd dur=$ddur"
if [ "$dvd" != h264 ]; then jr FAIL "dest verify failed"; exit 1; fi

jr DONE "ok"
echo ALL_OK
