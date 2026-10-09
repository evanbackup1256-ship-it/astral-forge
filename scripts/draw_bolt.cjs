const fs = require("node:fs");
const zlib = require("node:zlib");
const SIZE = 128, FRAMES = 12, COLUMNS = 4, AA = 3;
const width = SIZE * COLUMNS, height = SIZE * Math.ceil(FRAMES / COLUMNS);
const pixels = Buffer.alloc(width * height * 4);
const ink = [72, 39, 33], body = [246, 175, 94], light = [255, 220, 155];

function inside(x, y, points) {
  let hit = false;
  for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
    const [ax, ay] = points[i], [bx, by] = points[j];
    if ((ay > y) !== (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax) hit = !hit;
  }
  return hit;
}
function circle(x, y, cx, cy, rx, ry = rx) {
  return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1;
}
function stroke(x, y, points, thickness) {
  for (let i = 1; i < points.length; i++) {
    const [ax, ay] = points[i - 1], [bx, by] = points[i];
    const dx = bx - ax, dy = by - ay;
    const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)));
    if ((x - ax - dx * t) ** 2 + (y - ay - dy * t) ** 2 <= thickness ** 2 / 4) return true;
  }
  return false;
}
for (let frame = 0; frame < FRAMES; frame++) {
  const phase = frame % 4;
  const happy = frame >= 8, asleep = frame >= 6 && frame < 8, blink = frame === 4 || frame === 5;
  const flame = [-1, 1, 2, 0][phase];
  const outline = [[31 + flame, 5], [36, 13], [36, 20], [41, 16], [44, 26], [48, 33], [49, 42], [46, 49], [40, 54], [31, 56], [23, 54], [18, 49], [15, 41], [16, 33], [20, 26], [23, 18], [27, 23], [28, 13], [31 + flame, 5]];
  const interior = [[31 + flame, 9], [34, 15], [34, 24], [40, 20], [42, 27], [46, 34], [47, 42], [44, 48], [39, 52], [31, 54], [24, 52], [20, 48], [17, 40], [18, 34], [22, 28], [24, 22], [29, 27], [30, 14]];
  const smile = happy ? [[28, 45], [30, 48], [33, 48], [36, 44]] : [[29, 45], [32, 46], [35, 45]];
  function colorAt(x, y) {
    let color = null;
    if (circle(x, y, 19, 44, 6, 3.5) || circle(x, y, 46, 43, 5, 3)) color = ink;
    if (circle(x, y, 19, 44, 4, 1.8) || circle(x, y, 46, 43, 3.2, 1.5)) color = body;
    if (inside(x, y, outline)) color = ink;
    if (inside(x, y, interior)) color = y > 48 ? [227, 137, 78] : body;
    if (inside(x, y, [[30, 20], [33, 27], [29, 35], [21, 40], [20, 34], [24, 28], [27, 30]])) color = light;
    if (circle(x, y, 21, 35, 1.5, 3)) color = [255, 235, 191];
    if (happy && (circle(x, y, 23, 43, 3, 1.3) || circle(x, y, 40, 43, 3, 1.3))) color = [230, 120, 94];
    if (asleep || blink || happy) {
      for (const cx of [25, 39]) {
        const points = happy ? [[cx - 2, 40], [cx, 38], [cx + 2, 40]] : [[cx - 2, 40], [cx + 2, 40]];
        if (stroke(x, y, points, 1.8)) color = ink;
      }
    } else {
      for (const cx of [25, 39]) {
        if (circle(x, y, cx, 39.5, 2, 3.8)) color = ink;
        if (circle(x, y, cx - 0.4, 38, 0.6)) color = [255, 241, 213];
      }
    }
    if (stroke(x, y, smile, 1.7)) color = ink;
    return color;
  }
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const sums = [0, 0, 0];
    let covered = 0;
    for (let sy = 0; sy < AA; sy++) for (let sx = 0; sx < AA; sx++) {
      const color = colorAt((x + (sx + 0.5) / AA) / 2, (y + (sy + 0.5) / AA) / 2);
      if (color) { covered++; color.forEach((value, i) => sums[i] += value); }
    }
    if (covered) {
      const offset = ((Math.floor(frame / COLUMNS) * SIZE + y) * width + (frame % COLUMNS) * SIZE + x) * 4;
      sums.forEach((value, i) => pixels[offset + i] = Math.round(value / covered));
      pixels[offset + 3] = Math.round(255 * covered / (AA * AA));
    }
  }
}
function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(name, data) {
  const type = Buffer.from(name), size = Buffer.alloc(4), crc = Buffer.alloc(4);
  size.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([type, data])));
  return Buffer.concat([size, type, data, crc]);
}
const header = Buffer.alloc(13);
header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 6;
const raw = Buffer.alloc((width * 4 + 1) * height);
for (let y = 0; y < height; y++) pixels.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
fs.mkdirSync("assets\\authored", { recursive: true });
fs.writeFileSync("assets\\authored\\bolt.png", Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", header), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]));
console.log(`Drew ${FRAMES} Bolt poses: ${width}x${height}, transparent RGBA.`);
