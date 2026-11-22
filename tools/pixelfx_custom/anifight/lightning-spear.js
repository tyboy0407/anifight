// Anifight 自己寫的 pixelfx 特效:千鳥雷槍(宇智波佐助)。從手上射出去的一道筆直的雷電,朝右。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
// 圖長 length 像素;遊戲裡把它轉到要射的角度。
import { fit, wrap, WHITE, sparkle } from "../../core/index.js";
import { VOLT, zigzag, stroke, crackle, frameRng } from "../lightning/_lib.js";

export const meta = {
  name: "Lightning spear",
  desc: "A straight lance of lightning thrown from the hand: a hard white core tapering to a point, two bolts writhing along it and forking off, a flare at the hand and a star at the tip.",
  tags: ["lightning", "beam", "spear", "directional", "loop"],
  size: [480, 72],
  origin: [24, 36],
  duration: 0.2,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { palette: VOLT, length: 440, seed: 7 },
};

const D = meta.duration;

export function draw(p, time, o) {
  const t = wrap(time, D), f = Math.floor(t * meta.fps + 1e-6), C = fit(o.palette, 8), R = frameRng(o.seed, f), L = o.length;
  p.glowLine(0, 0, L, 0, 11, C[4], 0.3);
  // two bolts writhing along the lance
  for (let i = 0; i < 2; i++)
    stroke(p, zigzag(R, 4, R.range(-2, 2), L - 6, R.range(-2, 2), 0.03, 0), 0.9, C, 0.8, { light: 0.25 });
  // short crackles hopping off it
  for (let i = 0; i < 8; i++) {
    const x = R.range(20, L - 30), s = R.sign(), l = R.range(6, 14);
    crackle(p, zigzag(R, x, s * 2, x + R.range(-8, 14), s * l, 0.35, 0.1), 0.85, C, 0.2);
  }
  // the lance: a hard white core in a pale sheath, tapering to a point
  for (let x = 0; x <= L; x += 0.5) {
    const w = 2.6 * Math.min(1, (L - x) / 46) * Math.min(1, (x + 6) / 14);
    for (let y = -w; y <= w; y += 0.5) p.px(x, y, Math.abs(y) < w * 0.55 ? WHITE : C[6]);
  }
  // the flare at the hand and the star at the tip
  p.circle(0, 0, 5 + R.range(0, 1.5), C[6]);
  p.circle(0, 0, 3.2, WHITE);
  p.glow(0, 0, 14, WHITE, 0.5);
  sparkle(p, L, 0, 4 + R.range(0, 2), WHITE, C[5], 0.7);
}
