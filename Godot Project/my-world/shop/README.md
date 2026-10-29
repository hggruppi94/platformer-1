# Shop: what the market stalls sell

`items.json` lists everything the six stalls in the Market Square sell (`scripts/shop.gd` runs the shop;
`scripts/shop_stall.gd` is the "Press F to shop" spot at each stall). Prices are in **sparkles**, the bits of broken
time Nina finds round town (`scripts/sparkle.gd`) and earns from quests (`"sparkles"` in a quest's reward) and
happy places.

```json
{"id": "star_apple", "name": "Star Apple", "stall": "Fruit", "kind": "snack", "price": 2, "hp": 5, "text": "+5 HP"}
```

- `stall`: `Fruit`, `Sweets`, `Crystals`, `Flowers`, `Records` or `Toys`. `stalls` at the top has each one's welcome line.
  Things that are only ever given, not sold, have `"reward": true` and a stall no shop opens (`Dash`: his thank-yous
  for lost watches, `scripts/watches.gd`).
- `kind`:
  - `snack`: eaten straight away; `hp` and `mp` fill that much.
  - `hat`: kept, and worn one at a time.
  - `sticker`: goes on Rex's VOTE REX sash (so Nina needs the sash first).
- What a new hat or sticker looks like is built in `scripts/cosmetics.gd` (add a `match` case for its id; stickers
  also need a spot in `STICKER_ANGLES`).

Keep it kid-safe. Check your changes with
`godot --headless --path "Godot Project/my-world" --script res://tools/test_shop.gd`.
