# Google Play store assets

- `play/icon-512.png`, `play/feature-graphic.png`, `play/screenshots/` —
  upload in Play Console → Grow → Store presence → Main store listing.
- `play/listing/translations.csv` and `play/listing/<language>.txt` — the
  listing text in English, Telugu, Hindi, Tamil and Kannada.
- `raw/` — the app screens the screenshots frame, captured from the app
  with demo data (a demo temple and devotees; no real people).

Regenerate: `node tool/store/render.js` (graphics) and
`python3 tool/store/listing.py` (text). See docs/PLAY_LISTING.md.
