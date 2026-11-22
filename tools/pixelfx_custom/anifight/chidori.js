// Anifight 自己寫的 pixelfx 特效:千鳥(宇智波佐助)。凝聚在手上、劈啪作響的一團雷電。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
import { fit, wrap, TAU, WHITE } from "../../core/index.js";
import { VOLT, zigzag, stroke, crackle, frameRng } from "../lightning/_lib.js";

export const meta = {
  name: "Chidori",
  desc: "Lightning gathered in the hand: a white-hot knot throwing out long forked arcs and a bristle of short crackling ones, a new shape every frame, chattering like a flock of birds.",
  tags: ["lightning", "hand", "charge", "energy", "loop"],
  size: [88, 88],
  origin: [44, 44],
  duration: 0.3,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { palette: VOLT, radius: 9, seed: 5 },
};

const D = meta.duration;

export function draw(p, time, o) {
  const t = wrap(time, D), f = Math.floor(t * meta.fps + 1e-6), C = fit(o.palette, 8), R = frameRng(o.seed, f), r = o.radius;
  p.glow(0, 0, r * 2.8, C[4], 0.4);
  // a few long arcs that fork as they reach out
  for (let i = 0; i < 3; i++) {
    const a = R.range(0, TAU), l = r * R.range(2.2, 3.4);
    stroke(p, zigzag(R, 0, 0, Math.cos(a) * l, Math.sin(a) * l, 0.34, 0.6), 0.85, C, 0.75, { light: 0.3 });
  }
  // a bristle of short ones round the knot
  for (let i = 0; i < 7; i++) {
    const a = R.range(0, TAU), l = r * R.range(1.2, 2.1);
    crackle(p, zigzag(R, Math.cos(a) * r * 0.4, Math.sin(a) * r * 0.4, Math.cos(a) * l, Math.sin(a) * l, 0.4, 0.2), 0.9, C, 0.3);
  }
  // the knot itself, flickering in size
  const core = r * R.range(0.7, 0.95);
  p.circle(0, 0, core, C[6]);
  p.circle(0, 0, core * 0.62, WHITE);
  p.glow(0, 0, r * 1.5, WHITE, 0.45);
}
