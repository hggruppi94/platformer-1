# Quests

One file per quest, named after the quest's id: `rex_campaign.json` is the quest `rex_campaign`.
`scripts/quests.gd` (the `Quests` autoload) runs them. Progress is saved with the game, and a new game starts every
quest over.

```json
{
  "name": "Rex for Mayor!",
  "start": {"flag": "rex_campaign_start"},
  "steps": [
    {"id": "ask", "text": "Ask around town!", "done": {"flags": ["asked_dash", "asked_pip"]},
     "checklist": [["asked_dash", "Ask Dash"], ["asked_pip", "Ask Pip"]]},
    {"id": "posters", "text": "Hang the posters.", "wait": {"days": 1, "text": "Come back tomorrow!"},
     "done": {"flag": "posters_up"}}
  ],
  "reward": {"item": "campaign_sash", "message": "You got a sash!"},
  "titles": {"rex": "Future Mayor Rex"}
}
```

**How it moves along:** everything runs on **flags**, the same ones conversations use (`res://dialogue/README.md`).

- **`start`**: the quest starts once these flags are set. `{"flag": "x"}` or `{"flags": ["x", "y"]}`. Usually an
  answer in someone's conversation sets it (Rex: `"set": "rex_campaign_start"`).
- **`steps`**, in order. Each has an `id` (dialogue and quest spots refer to it), the `text` shown in the quest log
  and the note, and `done`: the flags that finish it. When they're all set, the next step starts.

**Where flags come from:**

- **Talking**: an answer's `"set"` in a conversation, or a whole conversation's `"set"` (set once it's over). Use the
  quest conditions below so the conversation only plays on the right step.
- **Places**: a quest spot (`scripts/quest_spot.gd`) sets its flag when Nina uses it, e.g. the four poster spots
  (`tools/build_town.gd`, `_rex_campaign()`). It only offers itself while its quest is on its step.
- **Time of day**: conversations can need a time (`"time": "evening"`) or what someone's doing in their routine
  (`"activity": "lamp_watching"`), so a step can need Nina to go at the right time.

**Extras a step can have:**

| Key | What it does |
| --- | --- |
| `"checklist": [["flag", "Label"], ...]` | shows each flag as a tick-box line in the quest log |
| `"wait": {"days": 1, "text": "..."}` | the step can't be done until this many days after it started (the day number, so sleeping past midnight counts). The text shows in the log while waiting |
| `"override": {"rex": {...}}` | while the step is on, that character follows this routine block instead of their schedule (same keys as `res://routines/README.md`, plus `"time"`: only during those times of day) |

**Changing the town:** a quest spot's `Done` child stays shown once its flag is set (Rex's posters, Bramble's
flowers), and its `Before` child only shows while it's waiting (Pip's glow shells). For bigger changes, give a node
`scripts/quest_show.gd` with `quest_done` (or `flag`): it shows from then on, for good (Pip's lit lanterns), or hides
with `hide_when_done` (the unlit ones). See `_town_quests()` in `tools/build_town.gd`.

**When it's done:** `reward.item` goes to Nina (`Game.give_item`), `reward.message` shows in the note, and `titles`
changes the name over someone's head (and in the talk box).

**Quest conditions for conversations** (add to `when` in `res://dialogue/<id>.json`):

| Key | Fits when |
| --- | --- |
| `"quest_not_started": "rex_campaign"` | the quest hasn't started |
| `"quest_step": "rex_campaign:ask"` | the quest is on that step |
| `"quest_ready": "rex_campaign:posters"` | on that step, and any `wait` is over |
| `"quest_waiting": "rex_campaign:posters"` | on that step, still waiting |
| `"quest_done": "rex_campaign"` | the quest is finished |

**In the game:** the quest log opens with **Q** (or Back/Select on a controller; it can be rebound in Settings).
A small note in the top-right corner shows when a quest starts, moves to a new step, or ends.

Keep it kid-safe. Check your changes with
`godot --headless --path "Godot Project/my-world" --script res://tools/test_quests.gd`.
