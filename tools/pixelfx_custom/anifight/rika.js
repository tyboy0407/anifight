// Anifight 自己寫的 pixelfx 生物:咒靈「里香」。漂浮的巨大咒靈,蒼白的頭、滿口利齒、長臂利爪,朝右。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
import { fit, hex, wrap, lerp, TAU } from "../../core/index.js";
import { Grid } from "../critters/_lib.js";

export const meta = {
  name: "Cursed spirit",
  desc: "A hulking pale-headed spirit floats on a tail of shadow: long hair down its back, a grin of jagged teeth, long clawed arms that flex; in strike mode it lunges and rakes forward.",
  tags: ["critter", "spirit", "curse", "monster", "summon", "float", "loop"],
  size: [92, 84],
  origin: [42, 80],
  duration: 1,
  loop: true,
  fps: 8,
  bg: "dark",
  options: {
    palette: ["#0b0812", "#1e1830", "#342a52", "#4f4074", "#7a68a8"],
    skin: ["#6f6a84", "#a9a4be", "#d6d2e4", "#f2f0f8", "#ffffff"],
    mouth: ["#3a0810", "#8a1420", "#e0303c"],
    mode: "idle",
    seed: 1,
  },
};

const D = meta.duration, GRID = new Grid(-38, -76, 86, 78);

function spirit(g, C, S, M, P) {
  g.clear();
  const DARK = C[2], PALE = S[2], FARP = S[1], bx = P.lean, by = P.bob;
  // 影子般的尾巴:從腰往下收細,尾端往後飄
  const tail = [];
  for (let i = 0; i <= 6; i++) {
    const u = i / 6;
    tail.push([bx * (1 - u) - u * u * 9 + Math.sin(P.ph * TAU + u * 4) * 2.2 * u, by - 30 + u * 26]);
  }
  g.tube(tail, (u) => 8.5 * (1 - u) ** 0.8 + 0.6, DARK);
  // 遠側的手臂(在身體後面)
  const fs = [bx - 9, by - 47], fh = P.far;
  g.tube([fs, [lerp(fs[0], fh[0], 0.5) - 3, lerp(fs[1], fh[1], 0.5)], fh], (u) => 2.8 - 0.6 * u, FARP);
  for (const k of [-1, 0, 1]) g.line(fh[0], fh[1], fh[0] + k * 1.6 - 0.5, fh[1] + 5, FARP);
  // 披在背後的長髮
  for (let k = 0; k < 4; k++) {
    const sx = bx - 2 - k * 2.2, pts = [];
    for (let i = 0; i <= 5; i++) {
      const u = i / 5;
      pts.push([sx - u * (5 + k * 2) + Math.sin(P.ph * TAU + k * 1.3 + u * 3) * 1.4 * u, by - 62 + u * (22 + k * 3)]);
    }
    g.tube(pts, (u) => 2.4 - 1.4 * u, k % 2 ? C[1] : DARK);
  }
  // 軀幹與寬肩
  g.ellipse(bx, by - 38, 11.5, 12.5, DARK);
  g.ellipse(bx - 8, by - 46, 6.5, 6, DARK);
  g.ellipse(bx + 8, by - 45, 6.5, 6, DARK);
  // 頭:蒼白,往前探
  const hx = bx + 5 + P.head, hy = by - 56;
  g.ellipse(hx, hy, 8.2, 8.6, PALE);
  // 頭頂與後腦的頭髮
  g.poly([[hx - 9, hy + 3], [hx - 9.5, hy - 6], [hx - 4, hy - 10.5], [hx + 4, hy - 10], [hx + 8.5, hy - 5], [hx + 5, hy - 6.5], [hx - 2, hy - 6], [hx - 5, hy - 1]], DARK);
  // 受光:蒼白的部分上亮下暗,深色的部分只在頂端有一圈冷色的邊光
  g.recolor((x, y, c) => {
    if (c === PALE) return !g.get(x, y + 1) || !g.get(x + 1, y + 1) ? S[1] : c;
    if (c === DARK) return !g.get(x, y - 1) ? C[4] : !g.get(x, y - 2) ? C[3] : !g.get(x, y + 1) ? C[1] : c;
    if (c === FARP) return !g.get(x, y + 1) ? S[0] : c;
    return c;
  });
  // 近側的手臂與爪(畫在身體前面)
  const ns = [bx + 9, by - 45], nh = P.near, el = [lerp(ns[0], nh[0], 0.5) + P.elbow[0], lerp(ns[1], nh[1], 0.5) + P.elbow[1]];
  g.tube([ns, el, nh], (u) => 3.2 - 0.5 * u, (u, d) => (d > 0.55 ? S[2] : S[3]));
  for (let k = -1; k <= 1; k++) {
    const a = P.claw + k * 0.42, L = 6.5 + (k === 0 ? 1 : 0);
    g.line(nh[0], nh[1], nh[0] + Math.cos(a) * L, nh[1] + Math.sin(a) * L, (u) => (u > 0.6 ? S[4] : S[3]));
  }
  // 臉:一隻發紅的眼、咧到耳邊的嘴與上下兩排利齒
  g.set(hx + 3, hy - 3, hex("#16080c")); g.set(hx + 4, hy - 3, M[2]); g.set(hx + 3, hy - 2, hex("#16080c")); g.set(hx + 4, hy - 2, hex("#16080c"));
  g.set(hx - 1, hy - 3, hex("#16080c")); g.set(hx - 1, hy - 2, hex("#16080c"));
  const open = P.jaw, my = hy + 2;
  for (let x = -4; x <= 6; x++) {
    for (let y = 0; y <= open + 1; y++) g.set(hx + x, my + y, y === 0 || y === open + 1 ? M[0] : M[1]);
    if ((x + 4) % 2 === 0) g.set(hx + x, my, S[4]);
    else g.set(hx + x, my + open + 1, S[4]);
  }
  g.set(hx - 5, my - 1, M[0]); g.set(hx + 7, my - 1, M[0]);
  // 輪廓:上緣是一圈冷色的邊光,在暗的場景裡才看得出身形
  g.outline((x, y, nx, ny) => (ny < 0 || nx < 0 ? C[3] : C[0]));
}

// 漂浮待機:上下浮動、手臂垂晃、爪子一張一合
function idle(ph) {
  const b = Math.sin(ph * TAU), b2 = Math.sin(ph * TAU * 2);
  return {
    ph, lean: 0, bob: Math.round(-9 + b * 1.6), head: 0, jaw: b2 > 0.5 ? 2 : 1,
    near: [19 + b * 1, -9 - 26 + b * 1.6 + b2], elbow: [3, -1], claw: 1.25 + 0.2 * b2,
    far: [-15 - b * 0.8, -9 - 30 + b * 1.6],
  };
}

// 揮爪:身體前傾,近側的手臂由上往前下方抓過去
function strike(ph) {
  const k = ph < 0.5 ? 0 : 1;
  return {
    ph, lean: 4, bob: -9, head: 2, jaw: 4,
    near: k ? [31, -34] : [27, -58], elbow: k ? [1, -4] : [4, 3], claw: k ? 0.7 : -0.5,
    far: [-13, -42],
  };
}

export function draw(p, time, o) {
  const ph = wrap(time, D) / D, C = fit(o.palette, 5), S = fit(o.skin, 5), M = fit(o.mouth, 3), g = GRID;
  const P = o.mode === "strike" ? strike(ph) : idle(ph);
  spirit(g, C, S, M, P);
  g.draw(p, 1, 0, 0);
  // 眼裡的紅光
  p.glow(P.lean + 9 + P.head, P.bob - 58, 4, M[2], 0.35);
}
