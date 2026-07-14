---
name: personal-video-to-ps4
description: >
  Convert local video files into PS4 Media Player-compatible MP4s, tag them, and
  copy them to a movies library. Use whenever the user wants to "convert to PS4",
  "make it play on PS4", "PS4 compatible format", batch-convert a Downloads folder
  of movies to a NAS/Movies drive, tag movies (title/year/genre), dedupe against an
  existing library, or fix "out of sync on PS4 but fine in VLC" audio. Handles MKV/
  AVI/TS/MP4 sources, HEVC/10-bit anime rips that "won't play on PS4", DTS/DD+ audio,
  SRT/ASS subs, whole-series batch conversions, and non-ASCII / bracketed filenames.
---

# Video → PS4

Convert videos to PS4 Media Player-compatible MP4, tag, copy to library. Prefer
lossless remux; only re-encode what PS4 can't play. Uses `ffmpeg`/`ffprobe`.

## PS4 Media Player compatibility (the rules that matter)

- **Container:** MP4. Always `-movflags +faststart`.
- **Video:** H.264 **≤ High@4.2**, **8-bit yuv420p**, **≤ 1920×1080**. Copy if already
  h264/yuv420p/≤1080p. Re-encode HEVC / H.265 / 10-bit (`yuv420p10le`) / MPEG-4 ASP,
  and **downscale anything >1080p** (4K won't play). Odd letterbox sizes (1920×816,
  1920×1040) are fine — don't "fix" them.
- **Audio:** AAC-LC or AC-3, **≤ 6ch (5.1)**. Copy those. Re-encode **DTS, E-AC-3/DD+
  (DDP), TrueHD, FLAC, Opus, 7.1** → AC-3 640k.
- **Subtitles:** text (`subrip`/`ass`) → `mov_text` (styling/positioning is lost —
  acceptable). **Drop image subs** (`hdmv_pgs_subtitle`, `dvd_subtitle`) — they can't
  go into MP4 and will fail the mux. Subtitles are OFF by default; user toggles in the
  PS4 player menu.
- **Filenames:** PS4 chokes on non-ASCII / `+` / `()`. Output ASCII: `Title_Year_PS4.mp4`.
- **Track order = default:** PS4 plays the **first** audio/sub track. Map the preferred
  language first and mark it `-disposition:a:0 default` (and clear others). Harmless
  log noise to ignore: `codec frame size is not set`, `Estimating duration from bitrate`,
  a leftover `bin_data` data stream.

## Workflow

1. **Probe** each source (loop `ffprobe -select_streams v/a/s`). Decide copy vs transcode per stream.
2. **Dedupe** against the library first: if the movie already exists there (exact file, or same movie/different release), **do nothing — just delete the source**. Only convert what's missing.
3. **Build locally, then `cp` to the library.** Never let ffmpeg write `+faststart` output directly to a slow/network volume — the two-pass moov move corrupts it (`moov atom not found`). Build on local disk, verify, then plain `cp`.
4. **Tag:** `-metadata title="…" -metadata year="YYYY" -metadata date="YYYY" -metadata genre="…"`. IMDb pages are behind a bot-wall (WAF) — don't scrape; tag title/year from filename + known facts.
5. **Verify** every output with `ffprobe` (streams + duration + tags) on the volume, then remove the source.
6. **Journal everything** (append-only `journal.jsonl`: START/DONE/FAIL/RM-SRC) so a killed/compacted run is resumable and deletions are auditable. Delete sources only AFTER the output is verified on the volume.

See `commands.md` for exact ffmpeg invocations and the batch-driver pattern.

## Gotchas hit in practice

- **"Out of sync on PS4 but fine in VLC" = edit-list/start-offset.** Audio has a
  container `start_time` > 0; VLC honors it, PS4 ignores it → audio early. Fix by
  **baking the offset as real silence**: extract audio to raw elementary stream
  (drops offset → t=0), `adelay=<ms>:all=1`, re-encode, remux with `start_time=0`.
  Verify first N seconds are silent via `volumedetect` (~ −90 dB). The same
  edit-list-ignore affects **subtitle** tracks — if subs also drift, re-time them too.
  **Guard (do this on every output):** check `a:0 start_time == 0`; if it isn't,
  the file will desync on PS4 → apply the bake-silence fix. (Container flags like
  `-avoid_negative_ts make_zero` do NOT reliably strip an existing edit list on a
  copy-remux; baking silence is the dependable fix.)
- **Multi-cut releases** bundle audio from different edits — track `DURATION`s differ
  (e.g. +7.8 s group). Pick the audio whose duration matches the video; a wrong pick
  desyncs. Check per-stream DURATION before mapping.
- **`.ts` files:** program often exposes ONE audio even if `ffprobe` lists several
  across programs — don't map `0:a:2` blindly. Use `-bsf:a aac_adtstoasc` for AAC→MP4.
- **Long jobs:** shell tool times out at 120 s. Run the batch with `nohup … &`, poll
  the journal/progress log. Copies to a NAS over SMB run ~30 MB/s — budget for it.
  **Poll via the journal, not `ls` on the NAS** — an SMB directory listing can itself
  blow the 120 s timeout on big folders. `grep -c 'DONE' journal.jsonl` is instant.
- **macOS Apple Silicon:** `h264_videotoolbox` is fast HW encode. Use
  `-c:v h264_videotoolbox -profile:v high -pix_fmt yuv420p -allow_sw 1 -tag:v avc1
  -b:v 8–12M -maxrate -bufsize`. Converts 10-bit → 8-bit automatically. (10-bit
  `yuv420p10le` / `High 10` is the #1 reason DVD-anime rips "don't play on PS4" —
  re-encode to 8-bit; audio is often already AAC/AC-3 so `-c:a copy` it.)
- **`start_time` can survive a videotoolbox RE-ENCODE, not just a copy-remux.** Even a
  full transcode with `-avoid_negative_ts make_zero` sometimes leaves a small residual
  audio `start_time` (e.g. 0.020 s) while video is 0 → PS4 plays audio slightly early.
  Always run the `a:0 start_time == 0` guard on the FINAL output (not just remuxes) and
  apply the bake-silence fix if nonzero. (Re-extracting audio to a raw elementary stream
  is what actually zeroes it; the `adelay` may round to 0 for tiny offsets and that's OK.)
- **CSV probe adds a trailing comma → false FAIL in batch verify.** `ffprobe … -of
  csv=p=0 -show_entries stream=codec_name` prints `ac3,` (trailing `,`), so a bash
  `[ "$x" = ac3 ]` check fails on a perfectly good file. Strip it: `| tr -d ',\n'`
  (or `.strip().strip(",")` in Python) before comparing. Don't delete/skip on this.
- **macOS `uchg` (user-immutable) flag blocks `rm` even in a writable dir.** Old library
  files (and some rips) have it set — `rm` returns "Operation not permitted" though
  `ls -lO` shows `uchg` and the parent dir is writable. Clear it first:
  `chflags nouchg "$SRC"` then `rm`. Put `chflags nouchg` in the batch driver right
  before every source delete so verified sources actually get removed.
- **Nasty filenames** (`[(`w´)]`, brackets, backticks, non-ASCII) break bash `*.mkv`
  glob expansion and quoting. For batches over such folders, drive with a **Python**
  script iterating `os.listdir()` and passing exact paths to ffmpeg/ffprobe — far more
  robust than shell globbing. Still rename OUTPUTS to ASCII `Title_NN_PS4.mp4`.
- Delete sources with `rm` only after verify — it does NOT go to Trash, so the journal
  is the only recovery record. Keep it.
