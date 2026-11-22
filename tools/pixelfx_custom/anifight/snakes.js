// Anifight 自己寫的 pixelfx 特效:白蛇(宇智波佐助的「大蛇之力」)。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
// mode:
//   "body"  蛇咬:從手上伸出去的蛇身,朝右,原點在手上。遊戲裡只露出目前伸出去的那一段。
//   "head"  蛇咬:張著嘴的蛇頭,朝右,原點在後頸(接在蛇身的末端)。
//   "crawl" 蛇籠:一小段地面上爬滿小白蛇,原點在地面中央。遊戲裡左右鋪好幾段。
//   "wrap"  蛇籠:纏在人身上的幾圈白蛇,原點在腳底;只畫蛇,不畫人。
import { hex, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "White snakes",
  desc: "Pale summoned snakes: a long body shot from the hand with scales rippling down it, a fanged head, a floor crawling with little ones, and coils wound round a victim.",
  tags: ["snake", "summon", "bind", "trap", "loop"],
  size: [208, 64],
  origin: [12, 32],
  duration: 0.4,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { mode: "body", length: 180, seed: 9 },
};

const D = meta.duration;
const WHITE = hex("#ffffff"), PALE = hex("#e4e6f2"), GREY = hex("#aab0c8"), SHADE = hex("#70789a"), DARK = hex("#3a3f5c");
const EYE = hex("#ffd23a"), MOUTH = hex("#b3263a"), TONGUE = hex("#ff5a6e");
// the floor modes are drawn round this point of the canvas (the importer anchors them here), not round the origin
export const FLOOR = [92, 26];

// one little snake crawling along the floor: a wave travelling down a short body, head leading
function little(p, x0, y0, len, dir, ph, s) {
  for (let d = 0; d <= len; d += 0.5) {
    const u = d / len, y = y0 + Math.sin(u * 5.5 - ph * TAU + s) * 1.6 * (0.4 + u * 0.6);
    const x = x0 - dir * d;
    p.px(x, y, u < 0.12 ? WHITE : u > 0.85 ? GREY : PALE);
    if (u < 0.75) p.px(x, y + 1, u < 0.12 ? PALE : SHADE);
  }
  p.px(x0 + dir, y0 - 1 + Math.sin(-ph * TAU + s) * 0.8, EYE);
}

export function draw(p, time, o) {
  const t = wrap(time, D), ph = t / D;
  if (o.mode === "head") {
    // the skull, snout right; the jaws gape and snap twice per loop
    const gape = 3 + 2.5 * (0.5 + 0.5 * Math.sin(ph * TAU * 2));
    p.poly([[-2, -4], [8, -6], [15, -gape], [15, -gape + 2], [6, -1], [-2, -1]], DARK);
    p.poly([[-2, 1], [6, 1], [14, gape - 1], [14, gape + 1], [8, 6], [-2, 4]], DARK);
    p.poly([[-1, -3.5], [8, -5], [14, -gape + 0.6], [6, -1.6], [-1, -1.6]], WHITE);
    p.poly([[-1, 1.6], [6, 1.6], [13, gape - 0.4], [8, 5], [-1, 3.4]], PALE);
    p.poly([[4, -1.5], [12, -gape + 1.5], [11, gape - 1.5], [4, 1.5]], MOUTH);
    // fangs, eye, a flick of tongue
    p.px(12, -gape + 2, WHITE); p.px(12, -gape + 3, WHITE);
    p.px(11, gape - 2, WHITE);
    p.px(5, -4, EYE); p.px(6, -4, EYE); p.px(6, -3, DARK);
    if (ph < 0.5) { p.px(9, 0, TONGUE); p.px(10, 0, TONGUE); p.px(11, ph < 0.25 ? -1 : 1, TONGUE); }
    p.glow(6, 0, 10, WHITE, 0.25);
    return;
  }
  if (o.mode === "crawl") {
    // a 96 px stretch of floor: little snakes at three depths, some heading each way
    const W = 96, [fx, fy] = FLOOR;
    for (let i = 0; i < 9; i++) {
      const dir = i % 3 === 0 ? -1 : 1, lane = i % 3, x = fx - W / 2 + 8 + ((i * 37) % (W - 16)), y = fy - 2 - lane * 4;
      little(p, x + dir * 3 * Math.sin(ph * TAU + i), y, 10 + (i % 4) * 2, dir, ph, i * 1.7);
    }
    p.glow(fx, fy - 4, 40, PALE, 0.12);
    return;
  }
  if (o.mode === "wrap") {
    // three coils round a body about 36 px tall: the near half of each ring in front, the far half darker
    const [fx, fy] = FLOOR;
    for (let i = 0; i < 3; i++) {
      const cy = fy - 8 - i * 10, rx = 9 - i * 0.6, ry = 2.6, spin = ph * TAU + i * 2.1;
      for (let a = 0; a < TAU; a += 0.05) {
        const x = fx + Math.cos(a) * rx, y = cy + Math.sin(a) * ry + Math.sin(a * 3 + spin) * 0.7, near = Math.sin(a) > 0;
        p.px(x, y, near ? (Math.sin(a * 6 - spin * 2) > 0.3 ? WHITE : PALE) : SHADE);
        if (near) p.px(x, y + 1, GREY);
      }
    }
    // two heads reared up at the shoulders, swaying
    for (const s of [-1, 1]) {
      const hx = fx + s * (7 + Math.sin(ph * TAU + s) * 1.2), hy = fy - 34;
      p.line(fx + s * 7, fy - 28, hx, hy, PALE);
      p.poly([[hx - 2, hy - 2], [hx + 2, hy - 2], [hx + 2.5, hy + 1], [hx - 2.5, hy + 1]], WHITE);
      p.px(hx + s, hy - 1, EYE);
    }
    p.glow(fx, fy - 18, 20, PALE, 0.18);
    return;
  }
  // "body": a long body leaving the hand, a wave rippling down it, lit on top, scaled underneath
  const L = o.length;
  for (let d = 0; d <= L; d += 0.5) {
    const u = d / L, y = Math.sin(d * 0.16 - ph * TAU) * 2.4 * Math.min(1, d / 14), w = 2.6 * Math.min(1, (d + 4) / 10);
    for (let q = -w; q <= w; q += 0.5) {
      const band = Math.floor((d + ph * 8) / 4) % 2 === 0;
      p.px(d, y + q, q < -w * 0.35 ? WHITE : q < w * 0.4 ? (band ? PALE : WHITE) : band ? GREY : SHADE);
    }
    p.px(d, y - w - 0.5, DARK);
    p.px(d, y + w + 0.5, DARK);
    if (u > 0.99) break;
  }
  p.glowLine(0, 0, L, 0, 7, PALE, 0.15);
}
