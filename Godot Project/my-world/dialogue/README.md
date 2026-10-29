# Dialogue: what people say

One file per character, named after the `character_id` on their talk spot (the `Talk` node under them in
`scenes/town/characters.tscn`): `dash.json`, `rex.json`, `rook.json`, `bramble.json`, `pip.json`, `green_man.json`, `astronaut.json` (by the Mothership Pad). Mr. Palmer (`mr_palmer.json`)
talks from behind his office window at the Town Hall.
`scripts/dialogue.gd` plays them.

```json
{
  "name": "Dash",
  "conversations": [
    {"when": {"talks": 0}, "lines": ["Hi! First time we've met!", "Nina: Hi Dash!"]},
    {"when": {"time": "night"}, "lines": ["It's late!"]},
    {"rotate": [["One visit says this."], ["The next visit says this."]]}
  ]
}
```

**Which conversation plays:** the first one in the list whose `when` fits right now. Put special ones first and a
plain one (no `when`) last, so there's always something to say.

**`when`** (all optional, and all of them must fit):

| Key | Fits when |
| --- | --- |
| `"time": "morning"` | the time of day where the player is (Earth's clock on Earth, Galaxity's in Galaxity) is that: `morning` (5-11 AM), `day` (11 AM-5 PM), `evening` (5-9 PM), `night` (9 PM-5 AM), `shift` (midnight-1 AM: on Earth the Shift itself, in Galaxity its midnight hour, when the portal glows brightest). `night` also fits then. Can be a list: `["evening", "night"]` |
| `"talks": 0` | Nina has talked to them exactly this many times before (0 = the first time) |
| `"min_talks": 3` / `"max_talks": 5` | at least / at most this many times before |
| `"every": 2` | every 2nd visit (handy so time-of-day lines take turns with the ordinary ones) |
| `"flag": "voted_rex"` / `"not_flag": "..."` | an earlier answer set that flag / didn't |
| `"activity": "riding"` | what they're up to in their daily routine (the block's `label` in `res://routines/<id>.json`). Can be a list |
| `"place": "town_hall"` | where their routine has them (a point in `res://routines/places.json`). Can be a list |
| `"travelling": true` | they're on their way somewhere |
| `"watches_to_give": true` | the player has lost watches they haven't given Dash yet (false: none). Also `"no_watches_yet": true` (none found at all), `"watches_found": 5` and `"watches_given": 5` (at least that many): see `scripts/watches.gd` |
| `"quest_step": "rex_campaign:ask"` | a quest is on that step. Also `quest_ready`, `quest_waiting`, `quest_done` and `quest_not_started`: see `res://quests/README.md` |

**`lines`** plays in order. **`rotate`** is a list of `lines` lists: each visit plays the next one in turn.
A conversation can have a **`"do": "Watches.watches_hand_in"`**: that autoload's method runs as the talk starts, and
any lines it gives back are said after the conversation's own (Dash taking the lost watches and giving rewards).
A conversation can have its own **`"set": "flag_name"`**: the flag is set once it's over (handy for quests: "told
Rex what everyone said").

**A line can be:**

- `"Hello!"`: said by the character.
- `"Nina: Hi!"`: said by Nina.
- `"(Dash wobbles.)"`: a line in brackets is narration, with no name shown.
- `{"speaker": "Bramble's friend", "text": "Och!"}`: said by someone else.
- A question with 2 or 3 answers:

```json
{"choice": [
  {"text": "Yes!", "lines": ["Great!"], "set": "said_yes"},
  {"text": "No thanks.", "lines": ["Okay!"]}
]}
```

  Nina says the answer she picks, then that answer's `lines` play, then the conversation carries on. Extras an answer
  can have: `"set": "flag_name"` remembers it (saved with the game), `"heal": true` fills HP/MP/SP,
  `"say": false` stops Nina from repeating the answer out loud, `"name": "Wiggles"` gives the character a name (shown
  over their head and in the talk box from then on), `"go": ["res://scenes/...tscn", "Entrance"]` takes her there
  once the conversation's over, and `"record": "scary_world_gate"` keeps a note of the answer (and the day and time)
  in the save's `dialogue.choices` list, for moments worth talking about later, like choosing whether to go into
  the Scary World.

**In any text:** `{time}` is the clock time, `{day}` the day number, `{talks}` how many times she's talked to them,
`{name}` their name, `{watches_given}`, `{watches_new}` and `{watches_left}` the lost watches, `{player}` the player's own name (from the character creator), `{they}` `{them}` `{their}` (and `{They}` `{Their}`) their pronouns, and `{quest_log}` the quest log's key.

Keep it kid-safe: no blood or violence. Check your changes with
`godot --headless --path "Godot Project/my-world" --script res://tools/test_dialogue.gd`: it checks every file can
be read and played.
