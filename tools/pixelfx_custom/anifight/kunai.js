// Anifight 自己寫的 pixelfx 特效:三叉苦無(波風湊的飛雷神苦無),朝右。
// 用 pixelfx(https://github.com/patch-gg/pixelfx,MIT)的繪圖工具寫成,由 tools/import_pixelfx.py 算圖。
// mode: "fly" 是飛行中(後面拖著風的線條),"still" 是插在定點上(握柄的術式一明一滅)。
import { cycle, hex, wrap, sparkle } from "../../core/index.js";

export const meta = {
  name: "Kunai",
  desc: "A three-pronged throwing knife flying right: a bright centre blade between two shorter prongs, a wrapped handle inked with a seal, a ring at its end, air streaking off behind it.",
  tags: ["projectile", "knife", "kunai", "throw", "directional", "loop"],
  size: [56, 24],
  origin: [30, 12],
  duration: 0.4,
  loop: true,
  fps: 20,
  bg: "dark",
  options: { mode: "fly", seed: 6 },
};

const D = meta.duration;
const EDGE = hex("#f4f8ff"), STEEL = hex("#aab6cc"), SHADE = hex("#5a6480"), WRAP = hex("#f0dc9a"), INK = hex("#3a2c20"), WIND = hex("#d8ecff"), SEAL = hex("#ffe060");

export function draw(p, time, o) {
  const t = wrap(time, D), ph = t / D, flying = o.mode !== "still";
  if (flying) {
    // air torn off the blades
    cycle(t, D, 7, o.seed * 5 + 1, D, (age, L, r) => {
      const k = age / L, y = r.pick([-3, -2, 0, 1, 3]), x0 = r.range(-12, -2) - k * 10, len = r.range(6, 13) * Math.sin(Math.PI * k);
      if (len < 1) return;
      p.line(x0, y, x0 - len, y, WIND, (u) => (1 - u) * (0.8 - 0.5 * k));
    });
  }
  // the ring at the end of the handle
  for (const [x, y] of [[-10, 0], [-9, -1], [-9, 1], [-8, 0]]) p.px(x, y, STEEL);
  // the handle: pale wrapping with the seal formula inked along it
  for (let x = -7; x <= -1; x++) p.px(x, 0, x % 2 ? WRAP : INK);
  for (let x = -6; x <= -1; x++) { p.px(x, -1, WRAP); p.px(x, 1, hex("#c8b070")); }
  // the two side prongs, with a gap between them and the centre blade
  for (const s of [-1, 1]) {
    p.px(0, s * 2, SHADE); p.px(1, s * 2, SHADE);
    for (let x = 1; x <= 5; x++) p.px(x, s * 3, s < 0 ? STEEL : SHADE);
    p.px(6, s * 3, EDGE);
  }
  // the centre blade: lit on top, shaded underneath
  for (let x = 0; x <= 10; x++) p.px(x, 0, x >= 9 ? EDGE : STEEL);
  for (let x = 1; x <= 7; x++) { p.px(x, -1, EDGE); p.px(x, 1, SHADE); }
  if (flying) {
    sparkle(p, 10, 0, 2 + Math.sin(ph * Math.PI * 2), EDGE, WIND, 0.5);
  } else {
    // the seal on the handle breathes with light: this is where he will appear
    const beat = 0.5 + 0.5 * Math.sin(ph * Math.PI * 2);
    p.glow(-4, 0, 7, SEAL, 0.25 + 0.3 * beat);
    if (beat > 0.6) p.px(-4, 0, SEAL);
  }
}
