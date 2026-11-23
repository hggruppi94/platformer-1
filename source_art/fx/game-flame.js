// The pixelfx effect behind the game's moving flames (Godot Project/my-world/scenes/fx/game_flame.png, played by
// scripts/fire_fx.gd on torches, lamps, candles, beacons and bonfires).
// To remake the sheet: put this file in a pixelfx checkout (https://github.com/patch-gg/pixelfx) as
// src/fx/fire/game-flame.js, run `node tools/render.mjs fire/game-flame --sheet` and copy
// records/fire/game-flame/game-flame.png over scenes/fx/game_flame.png (9 columns, 5 rows, 40 frames at 20 fps).

// The flame the Void's game puts on its torches, lamps, braziers and campfires: only the fire (the game's 3D model
// is the torch or the logs), drawn in the pack's fire colours; the game turns its hue for green, blue or lilac
// fires. Made from the pack's own fire recipe (burn() in _lib.js).
import { fit, rand } from "../../core/index.js";
import { noiseFor, hotFirst, burn } from "./_lib.js";

export const meta = {
  name: "Game flame",
  desc: "Just a licking flame with licks, puffs and embers, no prop or glow, in fire colours the game can hue-shift.",
  tags: ["fire", "flame", "loop", "tint"],
  size: [48, 80],
  origin: [24, 72],
  duration: 2,
  loop: true,
  fps: 20,
  bg: "dark",
  options: {
    palette: ["#4a1712", "#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"],
    seed: 4,
  },
};

const D = meta.duration, NL = noiseFor(D);
const TONGUES = [
  [-3.0, -1, 0.74, 3.2, 1],
  [3.2, -1, 0.7, 3.2, 1],
  [-5.4, 0.5, 0.42, 2.6, 0],
  [5.6, 0.5, 0.46, 2.6, 0],
  [0, 0, 1, 4.6, 0],
];

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), S = o.seed;
  burn(p, t, TONGUES, {
    H, D, NL, S, x: 0, y: -2, height: 30, lean: 0.12, spread: 7,
    puffs: 9, licks: 5, smoke: 0, smokeLife: [0.01, 0.02], embers: 9, glow: 0, wind: 2,
  });
}
