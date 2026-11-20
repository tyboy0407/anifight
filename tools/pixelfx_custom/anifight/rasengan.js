// Anifight 自己寫的 pixelfx 特效:螺旋丸(波風湊)。一顆高速旋轉的查克拉球。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
// radius 決定球的大小:手上的小顆與大招收尾的大顆是同一個特效算兩次。
import { fit, cycle, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Rasengan",
  desc: "A sphere of spinning wind held in the palm: a white-hot heart, three spiral arms whirling inside a thin bright shell, arcs of air orbiting outside it, flecks thrown off the rim.",
  tags: ["orb", "sphere", "wind", "spiral", "energy", "loop"],
  size: [96, 96],
  origin: [48, 48],
  duration: 0.3,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { palette: ["#0a1a4a", "#143a8a", "#2466c4", "#3c96ea", "#6cc4ff", "#a8e2ff", "#e0f6ff", "#ffffff"], radius: 28, seed: 4 },
};

const D = meta.duration;

export function draw(p, time, o) {
  const t = wrap(time, D), ph = t / D, C = fit(o.palette, 8), R = o.radius;
  p.glow(0, 0, R * 1.7, C[3], 0.3);
  // the ball: arms wound tighter towards the middle, turning a third of a turn per loop so it repeats seamlessly
  p.shade(-R - 1, -R - 1, R + 1, R + 1, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r > R) return;
    const q = r / R, arm = Math.sin(Math.atan2(y, x) * 3 + q * 6.5 - ph * TAU);
    let i = q < 0.2 ? 7 : q < 0.34 ? 6 : arm > 0.5 ? 6 : arm > -0.05 ? 5 : arm > -0.6 ? 4 : 3;
    if (r > R - 1.4) i = arm > 0 ? 7 : 6; // the shell
    else if (q > 0.74 && i > 3) i -= 1; // a shade darker just inside it, so it reads as a ball
    out.c = C[i];
  });
  // air dragged round the outside: six arcs, alternating near and far, the pattern repeating every third of a turn
  for (let k = 0; k < 6; k++) {
    const a0 = (ph * TAU) / 3 + (k * TAU) / 6, far = k % 2;
    p.arc(0, 0, R + 2.5 + far * (1.5 + R * 0.08), 1, a0, a0 + 0.55 + far * 0.25, far ? C[5] : C[7], far ? 0.75 : 0.95);
  }
  // flecks flung off the rim along the spin
  cycle(t, D, 5 + Math.round(R / 4), o.seed * 9 + 2, D, (age, L, r) => {
    const k = age / L, a = r.range(0, TAU) + k * 1.1, d = R + 2 + k * r.range(3, 5 + R * 0.25);
    p.dot(Math.cos(a) * d, Math.sin(a) * d, k < 0.5 ? C[7] : C[5], 1 - k);
  });
  p.glow(0, 0, R * 0.55, C[7], 0.45);
}
