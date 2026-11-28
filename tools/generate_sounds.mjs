// Generates soft UI sounds for FORGE. Usage: node tools/generate_sounds.mjs
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const DIR = path.join(ROOT, 'audio');
const SR = 22050;

function note(freq, dur, gain = 1) {
  const n = Math.floor(SR * dur);
  const out = new Float32Array(n);
  const attack = Math.max(1, Math.floor(SR * 0.008));
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    let env;
    if (i < attack) env = i / attack;
    else env = Math.exp(-3.2 * (i - attack) / (n - attack));
    const wave = Math.sin(2 * Math.PI * freq * t)
      + 0.3 * Math.sin(4 * Math.PI * freq * t)
      + 0.1 * Math.sin(6 * Math.PI * freq * t);
    out[i] = wave * env * gain;
  }
  return out;
}

function seq(notes, dur, gap, gain = 1) {
  const total = Math.floor(SR * (notes.length * gap + dur));
  const out = new Float32Array(total);
  notes.forEach((f, i) => {
    const buf = note(f, dur, gain / (1 + i * 0.08));
    const off = Math.floor(SR * i * gap);
    for (let j = 0; j < buf.length && off + j < total; j++) out[off + j] += buf[j];
  });
  return out;
}

function write(name, data) {
  let peak = 0;
  for (const v of data) peak = Math.max(peak, Math.abs(v));
  const scale = peak > 0 ? 0.55 / peak : 1;
  const bytes = Buffer.alloc(44 + data.length * 2);
  bytes.write('RIFF', 0);
  bytes.writeUInt32LE(36 + data.length * 2, 4);
  bytes.write('WAVE', 8);
  bytes.write('fmt ', 12);
  bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20);
  bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(SR, 24);
  bytes.writeUInt32LE(SR * 2, 28);
  bytes.writeUInt16LE(2, 32);
  bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36);
  bytes.writeUInt32LE(data.length * 2, 40);
  for (let i = 0; i < data.length; i++) {
    const v = Math.max(-1, Math.min(1, data[i] * scale));
    bytes.writeInt16LE(Math.round(v * 32000), 44 + i * 2);
  }
  fs.writeFileSync(path.join(DIR, name + '.wav'), bytes);
}

fs.mkdirSync(DIR, { recursive: true });
write('click', seq([880, 1320], 0.07, 0.035, 0.5));
write('toggle', seq([587.33, 880], 0.09, 0.05, 0.55));
write('case', seq([523.25, 659.25, 783.99, 1046.5], 0.16, 0.085, 0.75));
write('win', seq([659.25, 830.61, 987.77, 1318.51], 0.2, 0.1, 0.85));
write('lose', seq([349.23, 293.66], 0.28, 0.14, 0.6));
write('reward', seq([1046.5, 1567.98], 0.13, 0.09, 0.65));
write('daily', seq([783.99, 1046.5, 1318.51], 0.16, 0.1, 0.7));
console.log('sounds:', fs.readdirSync(DIR).join(', '));
