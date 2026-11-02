// The pixelfx effect behind Galaxity's tree twinkles (Godot Project/my-world/scenes/town/tree_twinkle.png).
// To remake the sheet: put this file in a pixelfx checkout (https://github.com/patch-gg/pixelfx) as
// src/fx/pickups/tree-twinkle.js, run `node tools/render.mjs pickups/tree-twinkle --sheet` and copy
// records/pickups/tree-twinkle/tree-twinkle.png over scenes/town/tree_twinkle.png.

import { fit, clamp, ease, WHITE } from "../../core/index.js";

// One twinkle on a leaf: a four-point star snaps open from a speck, flashes white, turns a little and shrinks
// back to a speck, then it is gone. Played with gaps between and started at different times, many copies
// read as a canopy that glitters at random. Light ramp, so a game can tint it any colour.

export const meta = {
  name: "Tree twinkle",
  desc: "A four-point star snaps open from a speck, flashes white, turns and shrinks away, so staggered copies with gaps between glitter.",
  tags: ["sparkle", "twinkle", "glint", "loop", "magic"],
  size: [32, 32], origin: [16, 16], duration: 0.8, loop: true, fps: 20, bg: "dark",
  options: { palette: ["#3a2a6a", "#7a6ad0", "#c8bff8", "#f0ecff"], seed: 1 },
};

const LIFE = 0.75;   // seconds the star is showing; a game spaces the loops out with empty time between

export function draw(p, t, o) {
  const C = fit(o.palette, 4);
  if (t >= LIFE) return;
  const u = t / LIFE;
  // Fast in, slow out: open over the first 18%, then shrink
  const grow = u < 0.18 ? ease.outQuart(u / 0.18) : 1 - ease.inQuad((u - 0.18) / 0.82);
  const arm = 2 + grow * 11;
  const hot = u > 0.12 && u < 0.26;   // the white hero frames
  // The long arms on the axes, tapering: white core, light middle, tinted tips
  const n = Math.round(arm);
  for (let d = 1; d <= n; d++) {
    const v = d / n;
    const c = hot && v < 0.6 ? WHITE : v < 0.35 ? WHITE : v < 0.7 ? C[2] : C[1];
    const a = v < 0.75 ? 1 : clamp(1.6 - v, 0, 1);
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) p.dot(dx * d, dy * d, c, a);
  }
  // Short diagonal glints once it's open, turning the star a little as it fades
  const dn = Math.round(arm * 0.26);
  for (let d = 1; d <= dn; d++) {
    const c = d === 1 ? C[3] : C[1];
    for (const [dx, dy] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) p.dot(dx * d, dy * d, c, d === 1 ? 1 : 0.7);
  }
  // A plus-shaped core
  p.px(0, 0, WHITE);
  if (arm > 5) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) p.px(dx, dy, WHITE);
  // Light: a soft pool and a tight hot one, brightest on the flash
  p.glow(0, 0, 4 + arm * 0.9, C[2], 0.25 + grow * 0.35);
  p.glow(0, 0, 3, WHITE, hot ? 0.8 : 0.35 * grow);
}
