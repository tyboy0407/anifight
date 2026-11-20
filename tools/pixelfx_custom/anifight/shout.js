// Anifight 自己寫的 pixelfx 特效:往前擴散的聲波(乙骨的咒言「飛走吧!」)。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
import { fit, clamp, ease, rng, sparkle } from "../../core/index.js";

export const meta = {
  name: "Shout",
  desc: "A shouted word made visible: three crescent pressure waves leave the mouth one after another, swelling as they race right, wind streaks between them, a flash at the lips.",
  tags: ["voice", "shout", "sound", "wave", "wind", "directional", "one-shot"],
  size: [176, 84],
  origin: [16, 42],
  duration: 0.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: ["#3a2a08", "#6b5210", "#a88420", "#d8b840", "#f2de7a", "#fff6c0", "#ffffff"], reach: 128, height: 58, seed: 2 },
};

const WAVES = 3, GAP = 0.07, LIFE = 0.3;

// one wave: a crescent bulging forward, its leading edge at x, half as tall as h
function wave(p, C, x, h, k) {
  const H = h / 2, R1 = H * 1.3, c1 = x - R1, tipX = c1 + Math.sqrt(R1 * R1 - H * H), c2 = c1 - H * 0.95, R2 = Math.hypot(tipX - c2, H);
  const thin = 1 - 0.4 * k;
  p.shade(tipX - 1, -H - 1, x + 1, H + 1, (px, py, out) => {
    if (Math.abs(py) >= H) return;
    const outer = c1 + Math.sqrt(R1 * R1 - py * py), inner = c2 + Math.sqrt(R2 * R2 - py * py), w = (outer - inner) * thin, edge = outer - px;
    if (edge < 0 || edge > w) return;
    out.c = edge < 1.2 ? C[6] : edge < 2.4 ? C[5] : k < 0.5 ? C[4] : C[3];
    // it thins towards the tips, and the whole wave dithers away as it runs out of breath
    out.a = clamp((H - Math.abs(py)) / (H * 0.35)) * clamp(1.5 - k * 1.5);
  });
  for (let y = -H * 0.7; y <= H * 0.7; y += 7) p.glow(c1 + Math.sqrt(R1 * R1 - y * y), y, 7, C[4], 0.22 * (1 - k));
}

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.reach, H = o.height;
  for (let i = 0; i < WAVES; i++) {
    const age = t - i * GAP;
    if (age < 0 || age >= LIFE) continue;
    const k = age / LIFE, e = ease.outCubic(k);
    wave(p, C, 12 + (R - 12) * e, H * (0.3 + 0.7 * e), k);
  }
  // wind dragged along between the waves
  for (let i = 0; i < 14; i++) {
    const g = rng(o.seed, i, 77), born = g.next() * 0.2, life = 0.14 + g.next() * 0.12, age = t - born;
    if (age < 0 || age >= life) continue;
    const k = age / life, y = (g.next() * 2 - 1) * H * 0.42, x0 = 6 + g.next() * 30 + ease.outCubic(k) * (R * 0.8), len = (8 + g.next() * 14) * Math.sin(Math.PI * k);
    p.line(x0, y, x0 - len, y, (u) => (u < 0.3 ? C[5] : C[3]), (u) => (1 - u) * (1 - k * 0.5));
  }
  // the word leaves the lips
  if (t < 0.12) {
    const k = t / 0.12;
    sparkle(p, 2, 0, 6 * (1 - k) + 2, C[6], C[4], 0.6 * (1 - k));
    p.glow(2, 0, 16, C[4], 0.4 * (1 - k));
  }
}
