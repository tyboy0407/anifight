// Anifight 自己寫的 pixelfx 特效:飛雷神的術式印記,貼在被標記的對手身上。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
import { fit, cycle, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Thunder mark",
  desc: "A small teleport seal burning on its target: a short column of inked glyphs glowing gold inside a turning broken ring, pulsing, with sparks lifting off it.",
  tags: ["status", "mark", "seal", "sigil", "loop"],
  size: [32, 32],
  origin: [16, 16],
  duration: 1.2,
  loop: true,
  fps: 15,
  bg: "dark",
  options: { palette: ["#4a2c00", "#8a5a08", "#d09a18", "#f8cc38", "#ffe878", "#fff8c8", "#ffffff"], seed: 8 },
};

const D = meta.duration;
// the glyphs, top to bottom: each row of a glyph is three pixels wide
const GLYPHS = [["#.#", ".#.", "###"], ["###", ".#.", "#.#"]];

export function draw(p, time, o) {
  const t = wrap(time, D), ph = t / D, C = fit(o.palette, 7), beat = 0.5 + 0.5 * Math.sin(ph * TAU * 2);
  p.glow(0, 0, 10, C[3], 0.25 + 0.2 * beat);
  // a dark backing so the seal reads on any outfit
  p.circle(0, 0, 6, C[0], 0.55);
  // a broken ring turning round the formula: four dashes in two shades, half a turn per loop so it repeats seamlessly
  for (let k = 0; k < 4; k++) {
    const a0 = (ph * TAU) / 2 + (k * TAU) / 4;
    p.arc(0, 0, 7.5, 1, a0, a0 + 1.0, k % 2 ? C[4] : C[5], 0.95);
  }
  // the column of glyphs, a wave of light running down it
  GLYPHS.forEach((rows, g) => {
    const lit = Math.sin((ph * 2 - g * 0.25) * TAU) > 0, y0 = -4 + g * 4;
    rows.forEach((row, j) => {
      for (let i = 0; i < 3; i++) if (row[i] === "#") p.px(-1 + i, y0 + j, lit ? C[6] : C[4]);
    });
  });
  // sparks lifting off it
  cycle(t, D, 5, o.seed * 3 + 1, D * 0.6, (age, L, r) => {
    const k = age / L, a = r.range(0, TAU), d = 8 + k * 4;
    p.dot(Math.cos(a) * d, Math.sin(a) * d - k * 4, k < 0.5 ? C[6] : C[3], 1 - k);
  });
}
