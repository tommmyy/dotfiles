# Commands

Assume `SRC` = source path, `OUT` = local build path, `MOVIES` = library dir.
Always end output opts with `-movflags +faststart`.

## Probe (decide per stream)

```bash
ffprobe -v error -select_streams v -show_entries stream=codec_name,profile,pix_fmt,width,height -of csv=p=0 "$SRC"
ffprobe -v error -select_streams a -show_entries stream=codec_name,channels:stream_tags=language,title,DURATION -of csv=p=0 "$SRC"
ffprobe -v error -select_streams s -show_entries stream=codec_name:stream_tags=language -of csv=p=0 "$SRC"
```

## Auto-decide copy vs transcode (per file)

```bash
read vcodec vpix vh < <(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,pix_fmt,height -of csv=p=0 "$SRC" | tr ',' ' ')
# video: copy only if h264 + yuv420p + <=1080p
if [ "$vcodec" = h264 ] && [ "$vpix" = yuv420p ] && [ "${vh:-0}" -le 1080 ]; then VMODE=copy; else VMODE=encode; fi
# audio: copy only if every audio stream is aac/ac3 with <=6ch
acs=$(ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$SRC")
if echo "$acs" | grep -qvE '^(aac|ac3)$'; then AMODE=ac3; else AMODE=copy; fi
echo "VMODE=$VMODE AMODE=$AMODE"
```

## Dedupe against library (skip = delete source)

```bash
# normalize a title key from a filename, then fuzzy-match existing library entries
key=$(basename "$SRC" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' ' ')   # -> words
# eyeball ls of the library filtered by the movie's distinctive word(s):
ls -la "$MOVIES" | grep -iE 'willyho|free.?willy'
# if a match exists (exact file OR same movie/other release): journal RM-DUP, rm "$SRC".
```

## Remux (already H.264/yuv420p + AAC/AC-3) — lossless, fast

```bash
ffmpeg -y -i "$SRC" -map 0:v:0 -map 0:a -c copy \
  -metadata title="Title" -metadata year="YYYY" -metadata date="YYYY" -metadata genre="…" \
  -movflags +faststart "$OUT"
```
- Text subs: add `-map 0:s -c:s mov_text` (only if subs are subrip/ass; else omit).
- `.ts` AAC: add `-bsf:a aac_adtstoasc`, map only the real audio (`0:a:0`).

## Transcode (HEVC / 10-bit / DTS / DD+) — Apple Silicon HW

```bash
ffmpeg -y -i "$SRC" \
  -map 0:v:0 -map 0:a:0 -map 0:s:0 \
  -c:v h264_videotoolbox -profile:v high -pix_fmt yuv420p -allow_sw 1 -tag:v avc1 \
  -b:v 10M -maxrate 14M -bufsize 20M \
  -c:a ac3 -b:a 640k \        # or -c:a copy if source audio is already aac/ac3
  -c:s mov_text \             # drop pgs/dvdsub by simply not mapping them
  -disposition:a:0 default \  # PS4 plays the first track; make preferred lang default
  -metadata:s:a:0 language=ces \
  -metadata title="Title" -metadata year="YYYY" -metadata date="YYYY" -metadata genre="…" \
  -fflags +genpts -avoid_negative_ts make_zero -movflags +faststart "$OUT"
```
Bitrate guide: 1080p live-action 10–12M, letterboxed/anime 8M.
**Downscale >1080p** (4K won't play): add before `-c:v` →
`-vf "scale=-2:'min(1080,ih)':flags=lanczos"` (keeps aspect, even dims).

## Level cap (rare, for finicky 1080p copies)

If a copied h264 stream is level > 4.2, PS4 may refuse it. Force via re-encode with
`-x264-params level=4.2` (sw) or just re-encode with videotoolbox as above.

## Copy to library (safe) + verify

```bash
cp -- "$OUT" "$MOVIES/Title_Year_PS4.mp4"
ffprobe -v error -show_entries format_tags=title,date,genre \
  -show_entries stream=codec_type,codec_name,profile -of default=noprint_wrappers=1 \
  "$MOVIES/Title_Year_PS4.mp4"
```

## Fix "in sync in VLC, off on PS4" (edit-list/start-offset)

```bash
# 1) auto-detect the offset in ms (audio a:0 start_time, video assumed 0)
OFF_MS=$(ffprobe -v error -select_streams a:0 -show_entries stream=start_time -of csv=p=0 "$CUR" \
         | awk '{printf "%d", $1*1000}')
echo "offset=${OFF_MS}ms"   # e.g. 2295

# 2) extract audio raw (drops container offset -> baseline t=0)
ffmpeg -y -i "$CUR" -map 0:a:0 -c copy audio.ac3

# 3) rebuild: bake OFF_MS of silence into audio, copy video, reset start_time=0
ffmpeg -y -i "$CUR" -i audio.ac3 \
  -map 1:a:0 -filter:a:0 "adelay=${OFF_MS}:all=1" -c:a:0 ac3 -b:a:0 640k \
  -map 0:v:0 -c:v copy \
  -map 0:s? -c:s copy \
  -metadata:s:a:0 language=ces \
  -movflags +faststart fixed.mp4

# 4) verify first seconds are silence, and start_time=0
ffmpeg -hide_banner -nostats -t "$(echo "$OFF_MS/1000" | bc -l)" -i fixed.mp4 -map 0:a:0 -af volumedetect -f null - 2>&1 | grep mean_volume  # ~ -90 dB
```

## 10-bit anime rip (DVD 10bit) — the "won't play on PS4" classic

Video is `h264 / High 10 / yuv420p10le`; audio is usually already AAC/AC-3 (copy it),
subs are `ass` (→ mov_text). Re-encode video to 8-bit only:

```bash
ffmpeg -y -i "$SRC" \
  -map 0:v:0 -map 0:a:0 -map 0:s? \
  -c:v h264_videotoolbox -profile:v high -pix_fmt yuv420p -allow_sw 1 -tag:v avc1 \
  -b:v 3M -maxrate 5M -bufsize 8M \   # SD 720x480 anime ~3M is plenty
  -c:a copy \                          # AAC/AC-3 already PS4-ok; don't re-encode
  -c:s mov_text \
  -disposition:a:0 default -metadata:s:a:0 language=jpn \
  -fflags +genpts -avoid_negative_ts make_zero -movflags +faststart "$OUT"
```

## Robust verify (avoid the CSV trailing-comma false-FAIL)

```bash
# csv=p=0 appends a trailing comma -> "ac3," ; strip it before comparing
vd=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$OUT" | tr -d ',\n')
ad=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$OUT" | tr -d ',\n')
vp=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt   -of csv=p=0 "$OUT" | tr -d ',\n')
st=$(ffprobe -v error -select_streams a:0 -show_entries stream=start_time -of csv=p=0 "$OUT" | tr -d ',\n')
[ "$vd" = h264 ] && [ "$vp" = yuv420p ] && [ "$ad" = aac -o "$ad" = ac3 ] || { echo BAD; }
# desync guard on the FINAL file (re-encodes can leave a residual start_time too):
awk -v s="$st" 'BEGIN{ if (s+0 > 0.001) print "NONZERO start_time -> bake silence" }'
```

## Delete a source that has the macOS uchg (immutable) flag

```bash
ls -lO "$SRC"                    # shows "uchg" if set; rm will say "Operation not permitted"
chflags nouchg "$SRC" && rm "$SRC"
```

## Batch driver pattern (many files)

- One journaled script; each job: skip-if-target-exists → START → ffmpeg to local
  `$OUT` → ffprobe-verify local (strip trailing comma!) → `cp` to `$MOVIES` →
  ffprobe-verify dest → DONE → `chflags nouchg` + `rm` source → journal `RM-SRC`.
  On any failure: journal FAIL, keep source.
- **Nasty filenames** (brackets/backticks/non-ASCII like `[(`w´)]_Show_-_01_…mkv`)
  break bash `*.mkv` globbing — drive the batch with a **Python** script that iterates
  `os.listdir()` and passes exact paths. Rename OUTPUTS to ASCII `Title_NN_PS4.mp4`.
- Order fast remuxes first (quick wins, frees space), heavy transcodes last.
- Launch: `nohup bash run.sh > progress.log 2>&1 &` (or `python3 run.py`) then poll
  `journal.jsonl` — NOT `ls` on the NAS (a slow SMB listing can hit the 120 s timeout).
  Progress = `grep -c 'DONE' journal.jsonl`; integrity = `RM count == DONE count`.
- Journal line: `printf '%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" STATUS TARGET NOTE >> journal.jsonl`
