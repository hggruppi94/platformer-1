# Music

Drop finished tracks into this folder with these exact names and they replace the placeholders automatically.
No code changes, no editor setup; the game picks up `<name>.ogg` (or `.mp3` / `.wav`) the next time you run it.

| File name           | Where it plays                                   | Mood                                             |
|---------------------|--------------------------------------------------|--------------------------------------------------|
| `earth_day.ogg`     | Stars Hollow by day (6:30 AM to 7:30 PM)         | Cosy autumn folk                                 |
| `earth_night.ogg`   | Stars Hollow at night                            | Halloween-cosy music box                         |
| `town_day.ogg`      | Galaxity in daylight                             | Dreamy, alien, wide-open; it plays a lot, so calm |
| `town_night.ogg`    | Galaxity at night                                | Slow and twinkly                                 |
| `skate_park.ogg`    | The Skate Park and the Hollow Skate Yard         | Upbeat and punky                                 |
| `race.ogg`          | Any race                                         | Fast, bright arps                                |
| `gloop_king.ogg`    | The Gloop King chasing you                       | A bouncy, goofy boss march                       |
| `scary_world.ogg`   | The Scary World                                  | Spooky but never scary                           |
| `festival.ogg`      | The Autumn Festival on the green                 | A happy jig                                      |
| `barn_dance.ogg`    | Madame Celeste's barn dance studio               | Four on the floor                                |
| `town.ogg`          | Galaxity, if `town_day`/`town_night` are missing | (placeholder)                                    |
| `interior.ogg`      | Aquarium, Cafe, Restaurant & Cafe, homes         | Cosy, small-room (placeholder)                   |
| `school.ogg`        | Inside the castle school                         | Playful, a little odd (placeholder)              |
| `behind_walls.ogg`  | Behind the Slivers (where the centipede lives)   | Unsettling: something is watching (placeholder)  |

`scripts/soundscape.gd` picks which one plays (a race, then the Gloop King, the festival, a music zone, the Scary
World, the skate parks, then the world and its time of day) and `scripts/audio.gd` crossfades to it. The first ten
are made by `tools/make_soundscape.py`, which also makes the ambience loops in `../ambience/`. Every sound's source is
in `../CREDITS.md`.

Tips for loops:
- Every track loops from the end straight back to the start, so make the last bar flow into the first.
  A loop of 1–3 minutes is plenty.
- OGG Vorbis is the best format for Godot (small, loops cleanly). Most DAWs export it; Audacity does too.
- Leave a little headroom (peaks around -3 dB). Music fades in and out over 1.5 s when you change area.
- To give one building its own track, add a new name to `SCENE_MUSIC` in `scripts/audio.gd`.

The placeholders in `placeholder/` were synthesized by `tools/make_placeholder_audio.py` and can be deleted
once all four real tracks are in.
