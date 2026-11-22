// Anifight 自己寫的 pixelfx 特效:麒麟(宇智波佐助)。一條龍形的雷電從天上撲下來,咬在地面上。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
// 原點是落雷的地面;雷從上方 height 像素的地方下來。
import { fit, clamp, ease, WHITE, hex } from "../../core/index.js";
import { VOLT, zigzag, bowed, stroke, crackle, frameRng } from "../lightning/_lib.js";

export const meta = {
  name: "Kirin",
  desc: "A dragon of lightning plunges from the sky: a horned head rides down a thick writhing bolt, bites the ground in a white flash, and arcs race away along the floor.",
  tags: ["lightning", "dragon", "strike", "thunder", "one-shot"],
  size: [320, 284],
  origin: [160, 262],
  duration: 0.75,
  loop: false,
  fps: 20,
  bg: "dark",
  options: { palette: VOLT, height: 232, seed: 11 },
};

const DROP = 0.16, HOLD = 0.34, EYE = hex("#1a0f5c");

// the head, snout down: a wedge-shaped skull, two swept-back horns, whiskers, eyes
function head(p, C, R, x, y, k) {
  const body = k > 0.8 ? WHITE : C[6], Z = 1.6, at = (dx, dy) => [x + dx * Z, y + dy * Z];
  // the glow it carries
  p.glow(x, y - 6, 34, C[4], 0.5 * k);
  // horns sweeping back up the bolt, and whiskers flung out from the snout
  for (const s of [-1, 1]) {
    stroke(p, zigzag(R, ...at(s * 8, -16), ...at(s * 19, -36), 0.18, 0.3), k, C, 1.1, { light: 0.2 });
    stroke(p, zigzag(R, ...at(s * 12, -10), ...at(s * 24, -22), 0.2, 0.2), k * 0.9, C, 0.8, { light: 0.1 });
    crackle(p, bowed(R, ...at(s * 5, 4), ...at(s * 25, -4), s * 6, 0.2, 0.2), k, C, 0.2);
    crackle(p, bowed(R, ...at(s * 4, 8), ...at(s * 19, 13), -s * 5, 0.2, 0.1), k, C, 0.2);
  }
  // the skull: broad across the brow, narrowing to the snout, edged in pale blue
  p.poly([at(-11, -18), at(11, -18), at(14, -8), at(9, 2), at(5, 14), at(-5, 14), at(-9, 2), at(-14, -8)], C[5]);
  p.poly([at(-9.5, -16.5), at(9.5, -16.5), at(12.5, -8), at(7.5, 1.5), at(3.8, 12.8), at(-3.8, 12.8), at(-7.5, 1.5), at(-12.5, -8)], body);
  // brow ridges over the eyes
  for (const s of [-1, 1]) p.poly([at(s * 2, -11), at(s * 12, -14), at(s * 12, -11.5)], C[4]);
  // the open jaws: a dark split up the snout, fangs either side
  p.poly([at(-2.2, 14), at(2.2, 14), at(0, 2)], C[2]);
  for (const s of [-1, 1]) p.poly([at(s * 2.4, 13), at(s * 4.6, 13), at(s * 3.6, 17)], WHITE);
  // slanted eyes, burning dark in the white skull
  for (const s of [-1, 1]) p.poly([at(s * 3, -8.5), at(s * 9.5, -10.5), at(s * 8, -6.5)], EYE);
}

export function draw(p, t, o) {
  const C = fit(o.palette, 8), H = o.height, f = Math.floor(t * meta.fps + 1e-6), R = frameRng(o.seed, f);
  const fall = clamp(t / DROP), fade = clamp((t - HOLD) / (meta.duration - HOLD)), k = 1 - fade;
  // where the head is: plunging, then biting the ground
  const hy = -H + 62 + (H - 88) * ease.inQuad(fall), hx = (1 - fall) * 14 * Math.sin(fall * 5);
  // the body: a thick bolt snaking down from the sky to the back of the head, redrawn every frame
  if (k > 0.05) {
    const sway = (y) => 12 * Math.sin(y * 0.045 + f * 1.7) * (1 - fade * 0.5);
    const top = [sway(-H) * 0.6, -H + 6], neck = [hx, hy - 26];
    const body = zigzag(R, top[0], top[1], neck[0], neck[1], 0.09, 1.1);
    body.paths.forEach((q) => q.pts.forEach((pt) => { pt[0] += sway(pt[1]) * clamp((neck[1] - pt[1]) / 40); }));
    stroke(p, body, k, C, 2.2 * (1 - fade * 0.6), { core: 2.6 * k, light: 0.5 });
    if (k > 0.4) stroke(p, zigzag(R, top[0] + R.range(-8, 8), top[1], neck[0], neck[1], 0.12, 0.6), k * 0.8, C, 1.0, { light: 0.2 });
  }
  if (k > 0.25) head(p, C, R, hx, hy, k);
  // the bite: a white flash on the ground, arcs racing away along the floor, a ring of light
  if (t >= DROP) {
    const u = clamp((t - DROP) / 0.2), late = clamp((t - DROP) / (meta.duration - DROP));
    p.glow(0, -6, 52 * (1 - late * 0.6), WHITE, 0.85 * (1 - late));
    p.glow(0, -4, 64, C[4], 0.5 * (1 - late));
    if (u < 1) p.ellipse(0, 0, 20 + 70 * u, 4 + 8 * u, WHITE, 0.9 * (1 - u));
    for (const s of [-1, 1])
      for (let i = 0; i < 3; i++) {
        const reach = (34 + 22 * i) * (0.4 + 0.6 * clamp(late * 2.2));
        stroke(p, bowed(R, s * 6, -2, s * reach, -R.range(0, 10), -s * R.range(4, 12), 0.25, 0.5), (1 - late) * 0.95, C, 0.8, { light: 0.2 });
      }
    for (let i = 0; i < 5; i++) {
      const a = -Math.PI * R.range(0.1, 0.9), l = R.range(18, 50) * (1 - late * 0.5);
      crackle(p, zigzag(R, 0, -4, Math.cos(a) * l, Math.sin(a) * l - 4, 0.3, 0.3), 1 - late, C, 0.25);
    }
  }
}
