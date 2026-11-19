// Anifight 自己寫的 pixelfx 生物:式神「玉犬」。額頭有紅色紋樣的白色大犬,側面朝右。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
import { fit, hex, wrap, TAU } from "../../core/index.js";
import { Grid } from "../critters/_lib.js";

export const meta = {
  name: "Spirit hound",
  desc: "A white hound with a red mark on its brow stands at heel, breathing, tail swishing, an ear flicking; in run mode it gallops flat out, legs gathering and stretching, jaws open.",
  tags: ["critter", "dog", "wolf", "hound", "summon", "loop"],
  size: [72, 52],
  origin: [34, 46],
  duration: 0.75,
  loop: true,
  fps: 8,
  bg: "ground",
  options: {
    palette: ["#16161f", "#474a5c", "#8386a0", "#b5b8cf", "#dcdfec", "#f3f5fb", "#ffffff"],
    mark: ["#7a1018", "#d8283a", "#ff7a70"],
    mode: "idle",
    seed: 1,
  },
};

const D = meta.duration, GRID = new Grid(-32, -44, 68, 48), LEG = 7;

// 兩節的腿:從關節到腳掌,中間的關節往後彎
function leg(g, jx, jy, fx, fy, c, r) {
  const dx = fx - jx, dy = fy - jy, d = Math.min(Math.hypot(dx, dy), LEG * 2 - 0.2), h = Math.sqrt(Math.max(0, LEG * LEG - (d * d) / 4));
  const mx = jx + dx / 2, my = jy + dy / 2, L = Math.hypot(dx, dy) || 1, kx = mx - (dy / L) * h * -1, ky = my + (dx / L) * h * -1;
  g.tube([[jx, jy], [kx, ky], [fx, fy]], (u) => r * (1 - 0.35 * u), c);
  g.set(fx, fy, c); g.set(fx + 1, fy, c);
}

function hound(g, C, M, S) {
  g.clear();
  const NEAR = C[4], FAR = C[2], hip = [-10, S.hipY], sho = [8, S.shoY];
  // 遠側的腿
  leg(g, hip[0] + 1.5, hip[1] + 2, S.feet[1][0], S.feet[1][1], FAR, 2.2);
  leg(g, sho[0] + 1.5, sho[1] + 3, S.feet[3][0], S.feet[3][1], FAR, 2);
  // 尾巴:蓬鬆,往上翹
  const ta = S.tail, tl = 10;
  g.tube([[hip[0] - 3, hip[1] - 2], [hip[0] - 3 - Math.cos(ta) * tl * 0.5, hip[1] - 2 - Math.sin(ta) * tl * 0.5 - 1], [hip[0] - 3 - Math.cos(ta) * tl, hip[1] - 2 - Math.sin(ta) * tl]],
    (u) => 2.2 + 1.2 * Math.sin(Math.PI * Math.min(1, u * 1.3)) - u, NEAR);
  // 軀幹:胸深、腰細
  g.tube([hip, [(hip[0] + sho[0]) / 2, (hip[1] + sho[1]) / 2 - S.arch], sho], (u) => 4.6 + 1.6 * u - 0.8 * Math.sin(Math.PI * u), NEAR);
  // 近側的腿
  leg(g, hip[0], hip[1] + 2, S.feet[0][0], S.feet[0][1], NEAR, 2.6);
  leg(g, sho[0], sho[1] + 3, S.feet[2][0], S.feet[2][1], NEAR, 2.3);
  // 脖子與頭
  const hx = sho[0] + 7 + S.headX, hy = sho[1] - 7 + S.headY;
  g.tube([[sho[0] + 1, sho[1] - 2], [hx - 1, hy + 1]], 4, NEAR);
  // 耳朵(遠側的較暗)
  g.poly([[hx - 1, hy - 3], [hx + 1.5 + S.ear, hy - 10], [hx + 3.5, hy - 3]], FAR);
  g.poly([[hx - 4.5, hy - 2.5], [hx - 3 + S.ear, hy - 10.5], [hx - 0.5, hy - 3.5]], NEAR);
  g.set(hx - 3 + S.ear, hy - 7, M[2]); g.set(hx - 3 + S.ear, hy - 6, M[2]);
  g.ellipse(hx, hy, 5, 4.6, NEAR);
  // 吻部,張嘴時下顎往下
  g.tube([[hx + 3, hy + 0.5], [hx + 9, hy + 1]], (u) => 2.6 - 0.7 * u, NEAR);
  if (S.jaw > 0) {
    g.tube([[hx + 3, hy + 3], [hx + 8, hy + 3 + S.jaw]], 1.3, C[3]);
    g.line(hx + 4, hy + 3, hx + 8, hy + 2.5 + S.jaw * 0.5, M[1]);
    g.set(hx + 8, hy + 2, C[6]); g.set(hx + 6, hy + 2, C[6]);
  } else g.line(hx + 5, hy + 3, hx + 9, hy + 3, M[0]);
  // 受光:每一塊毛的頂端最亮,腹側與腿的下緣轉暗
  g.recolor((x, y, c) => {
    if (c === NEAR) return !g.get(x, y - 1) ? C[6] : !g.get(x, y - 2) ? C[5] : !g.get(x, y + 1) ? C[2] : !g.get(x, y + 2) ? C[3] : c;
    if (c === FAR) return !g.get(x, y + 1) ? C[1] : c;
    return c;
  });
  // 鼻、眼、額頭的紋樣
  g.set(hx + 10, hy, C[0]); g.set(hx + 10, hy + 1, C[0]);
  if (S.blink) g.set(hx + 2, hy - 1, C[2]);
  else g.set(hx + 2, hy - 2, C[0]), g.set(hx + 2, hy - 1, C[0]), g.set(hx + 3, hy - 2, hex("#ffe9a8"));
  g.set(hx, hy - 4, M[1]); g.set(hx + 1, hy - 4, M[1]); g.set(hx + 1, hy - 3, M[1]); g.set(hx + 2, hy - 4, M[0]);
  g.outline((x, y, nx, ny) => (ny < 0 ? C[1] : C[0]));
}

// 站著:呼吸、搖尾巴、偶爾動一下耳朵、眨眼
function idle(ph) {
  const b = Math.sin(ph * TAU);
  return {
    hipY: -15, shoY: -16 - (b > 0.3 ? 1 : 0), arch: 0, headX: 0, headY: b > 0.3 ? 0 : 1,
    feet: [[-11, 0], [-8, 0], [9, 0], [12, 0]],
    tail: 0.9 + 0.5 * Math.sin(ph * TAU * 2), ear: ph > 0.62 && ph < 0.75 ? -1 : 0, blink: ph > 0.85 && ph < 0.97, jaw: 0,
  };
}

// 奔跑:前後腿輪流收攏與伸展,身體跟著弓起、拉平
function run(ph) {
  const foot = (cx, ax, off) => {
    const a = (ph + off) * TAU;
    return [cx + ax * Math.cos(a), -Math.max(0, -Math.sin(a)) * 6];
  };
  const k = Math.sin(ph * TAU);
  return {
    hipY: -15 + k * 1.5, shoY: -16 - k * 1.5, arch: 1.2 - k * 1.6, headX: 1, headY: -1 + k,
    feet: [foot(-11, 9, 0.5), foot(-8, 9, 0.6), foot(11, 10, 0), foot(14, 10, 0.1)],
    tail: 0.25 + 0.2 * k, ear: -2, blink: false, jaw: 2,
  };
}

export function draw(p, time, o) {
  const ph = wrap(time, D) / D, C = fit(o.palette, 7), M = fit(o.mark, 3), g = GRID;
  hound(g, C, M, o.mode === "run" ? run(ph) : idle(ph));
  g.draw(p, 1, 0, 0);
}
