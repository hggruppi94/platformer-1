// The cosmic dust's mote (scenes/fx/cosmic_mote.png, scripts/cosmic_dust.gd), made with pixelfx (MIT).
// Remake it: copy this file to pixelfx's src/fx/arcane/cosmic-mote.js, run
//   node tools/render.mjs arcane/cosmic-mote --sheet --no-actor
// and copy records/arcane/cosmic-mote/cosmic-mote.png over scenes/fx/cosmic_mote.png (7 x 6 cells of 24 px, 40 frames).
// A speck of cosmic dust for the Void's air: a soft glowing grain that breathes in and out while three tiny grains
// circle it, and once a loop it catches the light in a little four-point glint. Light ramp, so a game can tint each
// copy its own colour and start them at different times.
import { fit, WHITE, TAU } from "../../core/index.js";

export const meta = {
  name: "Cosmic mote",
  desc: "A breathing speck of glowing dust with three tiny grains circling it and a glint once a loop; tintable, made to be scattered by the hundred.",
  tags: ["cosmic", "dust", "mote", "ambient", "loop", "magic", "tint"],
  size: [24, 24], origin: [12, 12], duration: 2, loop: true, fps: 20, bg: "dark",
  options: { palette: ["#2c2a6a", "#6a6ad8", "#b8b4ff", "#eeeaff"], seed: 3 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 4);
  const u = t / meta.duration;
  const breathe = 0.5 + 0.5 * Math.sin(u * TAU);
  // the soft pool of light round it
  p.glow(0, 0, 4 + breathe * 3, C[1], 0.25 + breathe * 0.25);
  // the grain: a plus when it's bright, a single hot pixel when it's dim
  p.px(0, 0, breathe > 0.4 ? WHITE : C[3]);
  if (breathe > 0.55) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) p.dot(dx, dy, C[2], breathe);
  // three tiny grains circling on a tilted ring
  for (let i = 0; i < 3; i++) {
    const a = u * TAU + (i * TAU) / 3;
    const x = Math.cos(a) * 5, y = Math.sin(a) * 2.2;
    p.dot(Math.round(x), Math.round(y), Math.sin(a) > 0 ? C[2] : C[1], Math.sin(a) > 0 ? 1 : 0.6);
  }
  // a glint once a loop
  const g = u > 0.55 && u < 0.75 ? 1 - Math.abs(u - 0.65) / 0.1 : 0;
  if (g > 0) {
    const n = Math.round(1 + g * 4);
    for (let d = 2; d <= n; d++) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) p.dot(dx * d, dy * d, d === n ? C[1] : C[3], g);
    p.glow(0, 0, 3, WHITE, g * 0.6);
  }
}
