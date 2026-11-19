// Anifight 自己寫的 pixelfx 特效:飛行中的斬擊(宿儺的「解」)。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
import { fit, clamp, cycle, loopNoise, sparkle, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Air slash",
  desc: "A tall thin crescent of cutting force flying right: a white-hot leading edge, a paler belly that shimmers, wind streaks torn off its back and shavings shed behind.",
  tags: ["projectile", "slash", "cut", "directional", "loop"],
  size: [88, 72],
  origin: [56, 36],
  duration: 0.4,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { palette: ["#3a1418", "#6b2a2e", "#a55a5a", "#d49a96", "#f0d0cc", "#fff0ee", "#ffffff"], height: 50, seed: 1 },
};

const D = meta.duration;

export function draw(p, time, o) {
  const t = wrap(time, D), C = fit(o.palette, 7), H = o.height / 2, ph = t / D;
  // the crescent is the sliver between two circles that meet at its tips; the leading edge is the outer one
  const R1 = 30, c1 = -18, tipX = c1 + Math.sqrt(Math.max(0, R1 * R1 - H * H)), c2 = -36, R2 = Math.hypot(tipX - c2, H);
  const breathe = 1 + 0.12 * Math.sin(ph * TAU);
  // wind torn off its back: streaks that start on the blade and stretch away behind it
  cycle(t, D, 9, o.seed * 7 + 3, D, (age, L, r) => {
    const y = r.range(-H * 0.85, H * 0.85), k = age / L, x0 = c1 + Math.sqrt(Math.max(0, R1 * R1 - y * y)) - 4;
    const len = r.range(10, 26) * Math.sin(Math.PI * k), back = k * r.range(8, 20);
    if (len < 1) return;
    p.line(x0 - back, y, x0 - back - len, y, (u) => (u < 0.3 ? C[4] : u < 0.65 ? C[3] : C[2]), (u) => (1 - u) * (1 - k * 0.6));
  });
  // shavings flung off the tips
  cycle(t, D, 6, o.seed * 13 + 5, D, (age, L, r, i) => {
    const s = i % 2 ? 1 : -1, k = age / L, x = tipX - k * r.range(14, 30), y = s * (H - 1 + k * r.range(-3, 8));
    p.dot(x, y, k < 0.4 ? C[6] : C[4], 1 - k);
    if (k < 0.5) p.glow(x, y, 4, C[4], 0.3 * (1 - k));
  });
  p.shade(tipX - 3, -H - 1, c1 + R1 + 1, H + 1, (x, y, out) => {
    if (Math.abs(y) >= H) return;
    const outer = c1 + Math.sqrt(R1 * R1 - y * y), inner = c2 + Math.sqrt(R2 * R2 - y * y);
    const w = (outer - inner) * breathe, edge = outer - x;
    if (edge < 0 || edge > w) return;
    const q = edge / Math.max(0.5, w);
    // white on the leading rim, cooling inward; the belly shimmers along its length
    const sh = loopNoise(ph, 1.2, Math.floor((y + 40) / 3));
    let i = edge < 1.3 ? 6 : edge < 2.6 ? 5 : q < 0.6 ? 4 : 3;
    if (i <= 4 && sh > 0.62) i += 1;
    if (i <= 4 && sh < 0.34) i -= 1;
    out.c = C[i];
    out.a = clamp((H - Math.abs(y)) / 5 + 0.35);
  });
  // light along the edge, hottest at the middle; a glint that runs from tip to tip
  for (let y = -H; y <= H; y += 6) {
    const x = c1 + Math.sqrt(Math.max(0, R1 * R1 - y * y));
    p.glow(x - 1, y, 9, C[4], 0.28 * (1 - Math.abs(y) / (H + 6)));
  }
  p.glow(c1 + R1 - 2, 0, 20, C[3], 0.22);
  const gy = (ph * 2 - 1) * H * 0.8, gx = c1 + Math.sqrt(Math.max(0, R1 * R1 - gy * gy));
  sparkle(p, gx, gy, 3 + 2 * Math.sin(ph * Math.PI), C[6], C[4], 0.5);
}
