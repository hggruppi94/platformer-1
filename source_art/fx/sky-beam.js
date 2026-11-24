// The pixelfx effect behind the Seraph's beams of light from the sky (Godot Project/my-world/scenes/fx/sky_beam.png,
// played by scripts/starhorn.gd while a beam strikes).
// To remake the sheet: put this file in a pixelfx checkout (https://github.com/patch-gg/pixelfx) as
// src/fx/holy/sky-beam.js, run `node tools/render.mjs holy/sky-beam --sheet` and copy
// records/holy/sky-beam/sky-beam.png over scenes/fx/sky_beam.png (9 columns, 3 rows, 24 frames at 20 fps).

// Only the column of light (the game stretches it from the sky to the ground), in the pack's holy gold. The
// column recipe (bands of the ramp out from a white core, drifting strands, dithered edges) is the pack's loot
// beam, itself adapted from Sprite Fusion's open-source holy light
// (https://www.spritefusion.com/pixel-art-vfx/holy-light), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, smooth, rand, cycle, TAU, WHITE } from "../../core/index.js";
import { GOLD } from "./_lib.js";

export const meta = {
  name: "Sky beam",
  desc: "A column of holy light pouring straight down from the sky: a white core, gold bands, strands drifting through it and motes falling with it. Loops.",
  tags: ["holy", "beam", "light", "sky", "loop"],
  size: [64, 192],
  origin: [32, 190],
  duration: 1.2,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { palette: GOLD, seed: 5 },
};

const H = 188;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), T = meta.duration, ph = t / T;
  const shimmer = Math.floor(ph * 24);
  for (let y = -1; y >= -H; y--) {
    const h = -y - 0.5, u = h / H;
    // a little wider at the foot where it lands, and a pulse running down it
    const pulse = ((u * 2.5 + ph * 4) % 1 + 1) % 1 < 0.12 ? 1 : 0;
    const w = 8.5 + 3.5 * Math.exp(-h / 10) + Math.sin(h * 0.05 + ph * TAU) * 0.6;
    const X = Math.ceil(w * 1.6);
    for (let x = -X; x <= X; x++) {
      const q = Math.abs(x) / w;
      let lvl = q < 0.24 ? 0 : q < 0.47 ? 1 : q < 0.72 ? 2 : q < 1 ? 3 : 4;
      for (let s = 0; s < 3; s++) {
        const sx = (s - 1) * w * 0.55 + Math.sin(h * 0.07 - ph * TAU * (s + 1) + s * 2) * 1.1;
        if (Math.abs(x - sx) < 0.5) lvl = Math.max(0, lvl - 1);
      }
      if (rand(y, shimmer, 3) < 0.05 && lvl > 0) lvl--;
      if (q < 0.72) lvl = Math.max(0, lvl - pulse);
      // the core and inner bands are solid; only the fringe is dithered, and it frays more up high
      const a = lvl <= 2 ? 1 : ((1.55 - q) / 0.75) * (1.15 - 0.3 * u);
      if (a <= 0) continue;
      p.dot(x, y, lvl === 0 ? WHITE : C[7 - lvl], a);
    }
    if ((y & 3) === 0) p.glow(0.5, y, w * 2.2 + 4, C[5], 0.3 * (1 - 0.4 * smooth(0.7, 1, u)));
  }
  // motes falling with the light, a few twinkling
  cycle(t, T, 26, o.seed, (g) => g.range(0.5, 1.1), (age, life, r) => {
    const x = r.range(-14, 14), vy = r.range(160, 320), y = -H + r.range(0, 30) + vy * age;
    const k = Math.min(1, age / 0.15, (life - age) / 0.25);
    if (k <= 0 || y > -2) return;
    p.dot(x, y, Math.abs(x) < 5 ? C[5] : WHITE, k * 1.3);
    p.dot(x, y - 1, C[6], k);
    p.dot(x, y - 2, C[4], k * 0.6);
  });
}
