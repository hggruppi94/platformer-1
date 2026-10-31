# Audio credits

Every sound in the game is ours to ship: made in code for this game, or recorded/made by Hayden. Nothing is taken from
the show, from other games, or from sample packs. If you add a sound from somewhere else, it must be CC0 (public
domain), and it gets a line here with where it came from.

## Music (`audio/music/*.ogg`)

Written as data and synthesized from scratch by `tools/make_soundscape.py` (numpy + ffmpeg). Change a number in its
`SONGS` table and run it again; the same seed always makes the same track.

| Track | Where it plays | Made by |
|---|---|---|
| `earth_day.ogg` | Stars Hollow from 6:30 AM to 7:30 PM | `tools/make_soundscape.py` |
| `earth_night.ogg` | Stars Hollow at night | `tools/make_soundscape.py` |
| `town_day.ogg` | Galaxity in daylight | `tools/make_soundscape.py` |
| `town_night.ogg` | Galaxity at night | `tools/make_soundscape.py` |
| `skate_park.ogg` | Galaxity's Skate Park and the Hollow Skate Yard | `tools/make_soundscape.py` |
| `race.ogg` | Any race | `tools/make_soundscape.py` |
| `gloop_king.ogg` | When the Gloop King's after you | `tools/make_soundscape.py` |
| `scary_world.ogg` | The Scary World | `tools/make_soundscape.py` |
| `festival.ogg` | The Autumn Festival on the green | `tools/make_soundscape.py` |
| `barn_dance.ogg` | Madame Celeste's barn dance studio | `tools/make_soundscape.py` |
| `placeholder/*.ogg` | Interiors, the school, behind the Slivers | `tools/make_placeholder_audio.py` |

## Ambience (`audio/ambience/*.ogg`)

Also made by `tools/make_soundscape.py`: `birds`, `wind`, `water`, `mothership_hum`, `alien_chirps`, `market`.

## Made in the game's code (no files)

- The little feedback sounds (chime, pop, tick, whoosh, thud, sparkle, buzz): `scripts/juice.gd`.
- The talking blips and the Green Man's hum: `scripts/soundscape.gd`.
- The old oak's hum: `scripts/earth_town.gd`.

## Sound effects (`audio/sfx/*.wav`)

Made for this game by `tools/make_placeholder_audio.py` and earlier work in this repo.
