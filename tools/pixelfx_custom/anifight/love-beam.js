// Anifight 自己寫的 pixelfx 特效:又粗又長的咒力砲(乙骨與里香的「純愛砲」)。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
// The beam recipe (banded across, pulses running down it, sine strands that brighten in front, a source flare
// with spinning rays) follows pixelfx's arcane beam, which is adapted from Sprite Fusion's open-source energy beam
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, cycle, fract, wrap, TAU, WHITE } from "../../core/index.js";
import { bayer, mote } from "../arcane/_lib.js";

const D = 0.4;

export const meta = {
  name: "Love beam",
  desc: "A huge cannon blast pouring right from its muzzle: a white-hot core in banded pink, pulses racing down it, strands twisting round it, a flaring source, motes shed along its length.",
  tags: ["beam", "cannon", "laser", "blast", "directional", "loop"],
  size: [480, 104],
  origin: [36, 52],
  duration: D,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { palette: ["#3a0f2c", "#6b1f52", "#a23a7c", "#d560a6", "#f08cc4", "#ffb8dc", "#ffe0f0", "#ffffff"], length: 440, width: 22, seed: 3 },
};

export function draw(p, time, o) {
  const t = wrap(time, D), C = fit(o.palette, 8), ph = t / D, S = o.seed, L = o.length, W = o.width;
  // the body, built across from a white core out to a dithered edge, swelling in waves and pulsing as it goes
  const LV = [WHITE, C[6], C[5], C[4], C[3], C[2]];
  for (let d = 0; d <= L; d += 0.5) {
    const x = d, w = W * (1 + 0.1 * Math.sin(d * 0.11 - ph * TAU * 2)) * Math.min(1, (d + 10) / 26);
    const pulse = fract(d * 0.0125 - ph * 2) < 0.09 ? 1 : 0;
    for (let q0 = -w * 1.28; q0 <= w * 1.28; q0 += 0.5) {
      const q = Math.abs(q0) / w, y = q0;
      let lv = q < 0.26 ? 0 : q < 0.44 ? 1 : q < 0.64 ? 2 : q < 0.84 ? 3 : q < 1 ? 4 : 5;
      lv = Math.max(0, lv - pulse);
      if (lv === 5 && bayer(x, y) > (1.28 - q) / 0.28) continue;
      p.px(x, y, LV[lv]);
    }
    // four strands twisting round it: bright on the near side, gone behind
    for (let s = 0; s < 4; s++) {
      const a = d * 0.07 - ph * TAU * 2 + (s * TAU) / 4, off = Math.sin(a) * w * 1.08;
      if (Math.cos(a) > -0.15) {
        const c = Math.cos(a) > 0.55 ? WHITE : C[6];
        p.dot(x, off, c); p.dot(x, off + 1, c);
      }
    }
    if ((Math.round(d * 2) % 40) === 0) p.glow(x, 0, w * 1.9, C[4], 0.16);
  }
  // the source: a flickering ball of light with spinning rays where the blast leaves the muzzle
  const fr = W * 0.95 + Math.sin(ph * TAU * 3) * 1.5;
  for (let i = 0; i < 6; i++) {
    const a = ph * TAU + (i * TAU) / 6, l = W * 1.5 + 4 * Math.sin(ph * TAU * 2 + i * 2);
    p.line(0, 0, Math.cos(a) * l, Math.sin(a) * l, (u) => (u < 0.6 ? WHITE : C[6]), (u) => (u < 0.7 ? 1 : 1.7 - u));
  }
  p.circle(0, 0, fr + 2.5, C[4]);
  p.circle(0, 0, fr, C[6]);
  p.circle(0, 0, fr * 0.7, WHITE);
  p.glow(0, 0, W * 2, C[5], 0.5);
  // motes shed along the beam, carried forward
  cycle(t, D, 40, S * 3 + 4, D, (age, life, r) => {
    const q = age / life, x = r.range(20, L - 30) + q * 30, y = r.sign() * (W * 1.2 + 2 + q * r.range(4, 14));
    mote(p, x, y, 60, y * 1.2, r.chance(0.5) ? C[6] : C[5], 0.7, 1 - q, 0.3);
  });
}
