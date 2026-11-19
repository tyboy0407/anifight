// Anifight 自己寫的 pixelfx 生物:式神「鷲」。戴著骨面具的大型猛禽,正面拍翅。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
import { fit, hex, lerp, wrap } from "../../core/index.js";
import { Grid } from "../critters/_lib.js";

export const meta = {
  name: "Mask owl",
  desc: "A big owl in a bone mask beats its banded wings in four snappy frames, body lifting on each downbeat; in dive mode it folds its wings back and reaches with its claws.",
  tags: ["critter", "owl", "bird", "summon", "flying", "loop"],
  size: [76, 64],
  origin: [38, 34],
  duration: 0.5,
  loop: true,
  fps: 8,
  bg: "sky",
  options: {
    palette: ["#1c0f0a", "#3b2114", "#5e3620", "#8a5330", "#b87a48", "#dba872", "#f6dcae"],
    bone: ["#6f6858", "#b3aa94", "#e6dfcc", "#fffaf0"],
    claw: ["#8a3d10", "#f08a24", "#ffd27a"],
    mode: "fly",
    seed: 1,
  },
};

const D = meta.duration, GRID = new Grid(-34, -30, 68, 58);
// 右翼的四個拍翅姿勢:上臂的角度與長度、四根初級飛羽的角度與長度、身體跟著起伏的量
const FLY = [
  { arm: -52, al: 9, f: [-98, -74, -50, -24], fl: [12, 15, 15, 13], sl: 10, lift: 1 },
  { arm: -14, al: 10, f: [-34, -12, 10, 32], fl: [13, 15, 15, 13], sl: 10, lift: 0 },
  { arm: 28, al: 9, f: [30, 52, 74, 98], fl: [11, 14, 14, 12], sl: 8, lift: -2 },
  { arm: -34, al: 7, f: [-62, -38, -14, 10], fl: [9, 11, 11, 10], sl: 8, lift: -1 },
];
// 俯衝:翅膀往後上方收成 V 字,微微顫動
const DIVE = [
  { arm: -64, al: 9, f: [-108, -90, -72, -50], fl: [13, 16, 15, 12], sl: 11, lift: 0 },
  { arm: -60, al: 9, f: [-104, -86, -68, -46], fl: [13, 16, 15, 12], sl: 11, lift: 1 },
];
const rad = (d) => (d * Math.PI) / 180;

function wing(F, s) {
  const sh = [s * 3.5, -4], ar = rad(F.arm), wr = [sh[0] + s * Math.cos(ar) * F.al, sh[1] + Math.sin(ar) * F.al];
  const tips = F.f.map((d, i) => [wr[0] + s * Math.cos(rad(d)) * F.fl[i], wr[1] + Math.sin(rad(d)) * F.fl[i]]);
  const pull = (a, b, k) => [lerp((a[0] + b[0]) / 2, wr[0], k), lerp((a[1] + b[1]) / 2, wr[1], k)];
  const hip = [s * 3, 6];
  // 次級飛羽:從上臂往後下方垂的一排,讓翅膀是一整片而不是一根手臂
  const back = rad(F.f[F.f.length - 1] + 42), sec = [0.72, 0.36].map((k, i) => {
    const ax = lerp(sh[0], wr[0], k), ay = lerp(sh[1], wr[1], k), L = F.sl * (i ? 0.85 : 1);
    return [ax + s * Math.cos(back) * L, ay + Math.sin(back) * L];
  });
  const poly = [sh, wr, tips[0]];
  for (let i = 1; i < tips.length; i++) poly.push(pull(tips[i - 1], tips[i], 0.16), tips[i]);
  poly.push(pull(tips[tips.length - 1], sec[0], 0.12), sec[0], pull(sec[0], sec[1], 0.1), sec[1], hip);
  return { sh, wr, tips, hip, poly };
}

function owl(g, C, B, K, F, dive) {
  g.clear();
  for (const s of [-1, 1]) {
    const w = wing(F, s), lit = s < 0 ? 1 : 0;
    // 翅膀:靠身體的覆羽較亮,初級飛羽有一圈圈深色橫斑,前緣一條亮邊
    g.poly(w.poly, (x, y) => {
      const d = Math.hypot(x - w.wr[0], y - w.wr[1]), near = Math.hypot(x - w.sh[0], y - w.sh[1]);
      if (near < 5.5) return C[4 + lit];
      if (d < 3.5) return C[4];
      return Math.floor(d / 2.6) % 2 ? C[2] : C[3 + lit];
    });
    g.line(w.sh[0], w.sh[1], w.wr[0], w.wr[1], C[5]);
    g.line(w.wr[0], w.wr[1], w.tips[0][0], w.tips[0][1], (u) => (u < 0.7 ? C[5] : C[4]));
    for (const tip of w.tips.slice(1)) g.line(w.wr[0], w.wr[1], lerp(w.wr[0], tip[0], 0.55), lerp(w.wr[1], tip[1], 0.55), C[4]);
  }
  // 尾羽
  g.poly([[-3.5, 5], [3.5, 5], [5, 11], [0, 12.5], [-5, 11]], (x, y) => (Math.floor(y) % 3 === 0 ? C[2] : C[3]));
  // 身體:左上受光,胸口有淺色的 V 形斑
  g.ellipse(0, 1.5, 5.6, 7, (nx, ny) => {
    if (nx * -0.6 + ny * -0.8 > 0.5) return C[5];
    if (nx * 0.6 + ny * 0.8 > 0.55) return C[2];
    return C[4];
  });
  for (const [x, y] of [[-2, 2], [1, 2], [-1, 4], [2, 4], [-3, 5], [0, 6]]) g.set(x, y, C[6]);
  // 爪:平常收在腹下,俯衝時往前下方張開
  if (dive) {
    for (const s of [-1, 1]) {
      g.line(s * 2.5, 7, s * 4.5, 12, K[1]);
      for (const dx of [-1.5, 0, 1.5]) g.line(s * 4.5, 12, s * 4.5 + dx, 15, dx === 0 ? K[2] : K[1]);
    }
  } else {
    for (const s of [-1, 1]) g.set(s * 2.5 - 0.5, 8.5, K[1]), g.set(s * 2.5 - 0.5, 9.5, K[0]);
  }
  // 頭:羽角、蓋住整張臉的骨面具、深陷的眼窩裡一點橘光、鉤狀的喙
  for (const s of [-1, 1]) g.poly([[s * 1.5, -11], [s * 6.2, -15.5], [s * 5.6, -8]], s < 0 ? C[4] : C[3]);
  g.ellipse(0, -7.5, 5.8, 5, (nx, ny) => (nx * -0.6 + ny * -0.8 > 0.35 ? C[4] : C[3]));
  g.ellipse(0, -6.8, 4.9, 4.2, (nx, ny) => (nx * -0.5 + ny * -0.85 > 0.45 ? B[3] : nx > 0.45 || ny > 0.6 ? B[1] : B[2]));
  for (const s of [-1, 1]) {
    const ex = s < 0 ? -3 : 1;
    for (let dx = 0; dx < 2; dx++) for (let dy = 0; dy < 2; dy++) g.set(ex + dx, -8 + dy, hex("#120a0c"));
    g.set(ex + (s < 0 ? 1 : 0), -7, K[1]);
  }
  g.set(-1, -5, K[1]); g.set(0, -5, K[1]); g.set(-1, -4, K[0]);
  g.line(-1, -11, -1, -9.5, B[1]);
  g.outline(C[0]);
}

export function draw(p, time, o) {
  const dive = o.mode === "dive", list = dive ? DIVE : FLY, t = wrap(time, D);
  const C = fit(o.palette, 7), B = fit(o.bone, 4), K = fit(o.claw, 3);
  const F = list[Math.floor((t / D) * 4) % list.length], g = GRID, Y = F.lift;
  owl(g, C, B, K, F, dive);
  g.draw(p, 1, 0, Y);
  // 眼窩裡的光、面具上的月光
  p.glow(-2, Y - 10, 8, B[3], 0.08);
}
