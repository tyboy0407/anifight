// Anifight 自己寫的 pixelfx 特效:燃燒狀態(被豪火球打中的對手)。身上幾處冒著小火,火星往上飄。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
// 原點在腳底;只畫火,不畫人,所以可以疊在任何角色身上。
import { fit, cycle, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Burn",
  desc: "Someone on fire, without the someone: four small flames lick up from head, shoulder, hip and leg height, swaying and flaring out of step, embers lifting off them and winking out.",
  tags: ["status", "fire", "burn", "dot", "debuff", "loop"],
  size: [48, 64],
  origin: [24, 56],
  duration: 0.6,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { palette: ["#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"], seed: 3 },
};

const D = meta.duration;
// where the flames sit on a fighter about 36 px tall: [x, y, height, width, phase]
const SPOTS = [[-3, -35, 9, 5, 0], [6, -25, 7, 4, 2.1], [-7, -17, 8, 4.5, 4.0], [4, -7, 7, 4, 5.3]];

function flame(p, C, x0, y0, h, w, ph, s) {
  const tall = h * (1 + 0.22 * Math.sin(ph * TAU * 2 + s));
  for (let py = 0; py <= tall; py += 0.5) {
    const u = py / tall, half = (w / 2) * Math.pow(1 - u, 0.75) * (1 + 0.2 * Math.sin(ph * TAU + u * 6 + s));
    const lean = Math.sin(ph * TAU + s * 1.7 + u * 3) * u * 2.2;
    for (let dx = -half; dx <= half; dx += 0.5) {
      const q = Math.abs(dx) / Math.max(0.5, half);
      // white-hot at the root, yellow up the middle, orange at the skin, red at the tip
      const i = u < 0.25 && q < 0.5 ? 7 : u < 0.5 && q < 0.55 ? 5 : u < 0.72 ? (q < 0.6 ? 4 : 3) : u < 0.88 ? 2 : 1;
      p.px(x0 + dx + lean, y0 - py, C[i]);
    }
  }
  p.glow(x0, y0 - tall * 0.3, w * 1.6, C[3], 0.3);
}

export function draw(p, time, o) {
  const t = wrap(time, D), ph = t / D, C = fit(o.palette, 8);
  for (const [x, y, h, w, s] of SPOTS) flame(p, C, x, y, h, w, ph, s);
  // embers lifting off, drifting a little, cooling as they rise
  cycle(t, D, 9, o.seed * 7 + 2, D, (age, L, r) => {
    const k = age / L, [x, y, h] = r.pick(SPOTS), drift = r.range(-5, 5);
    p.dot(x + drift * k + Math.sin(k * 6 + drift) * 1.2, y - h - k * r.range(8, 16), k < 0.4 ? C[6] : k < 0.7 ? C[4] : C[2], 1 - k);
  });
}
