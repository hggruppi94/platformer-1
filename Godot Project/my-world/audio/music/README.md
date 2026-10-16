# Music

Drop finished tracks into this folder with these exact names and they replace the placeholders automatically.
No code changes, no editor setup; the game picks up `<name>.ogg` (or `.mp3` / `.wav`) the next time you run it.

| File name           | Where it plays                                   | Mood (placeholder's idea, change freely)         |
|---------------------|--------------------------------------------------|--------------------------------------------------|
| `town.ogg`          | The town, outdoors                               | Dreamy, alien, wide-open; it plays a lot, so calm |
| `interior.ogg`      | Aquarium, Cafe, Restaurant & Cafe                | Cosy, small-room                                 |
| `school.ogg`        | Inside the castle school                         | Playful, a little odd                            |
| `behind_walls.ogg`  | Behind the Slivers (where the centipede lives)   | Unsettling: something is watching                |

Tips for loops:
- Every track loops from the end straight back to the start, so make the last bar flow into the first.
  A loop of 1–3 minutes is plenty.
- OGG Vorbis is the best format for Godot (small, loops cleanly). Most DAWs export it; Audacity does too.
- Leave a little headroom (peaks around -3 dB). Music fades in and out over 1.5 s when you change area.
- To give one building its own track, add a new name to `SCENE_MUSIC` in `scripts/audio.gd`.

The placeholders in `placeholder/` were synthesized by `tools/make_placeholder_audio.py` and can be deleted
once all four real tracks are in.
