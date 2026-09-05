import fs from 'node:fs';
import * as THREE from 'three';
import { TRACK_LAYOUTS } from '../src/track-layouts.generated.js';

const WORLD_SCALE = 2.075;
const ROAD_HALF_WIDTH = 16.2 / 2;
const SAMPLE_COUNT = 2048;
// 与运行时 buildTrackClearance 的 24 / 1040 圈长排除范围保持一致。
const MIN_SEPARATION_SAMPLES = Math.round(SAMPLE_COUNT * 24 / 1040);

function readPoints(key) {
  if (!TRACK_LAYOUTS[key]) throw new Error(`points not found: ${key}`);
  const minElevation = Math.min(...TRACK_LAYOUTS[key].map((point) => point[2]));
  return TRACK_LAYOUTS[key].map(([x, z, y]) => new THREE.Vector3(x * WORLD_SCALE, (y - minElevation) * .52, z * WORLD_SCALE));
}

function orient(a, b, c) { return (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x); }
function onSegment(a, b, p) { return Math.min(a.x, b.x) <= p.x && p.x <= Math.max(a.x, b.x) && Math.min(a.z, b.z) <= p.z && p.z <= Math.max(a.z, b.z); }
function segmentsCross(a, b, c, d) {
  const ab1 = orient(a, b, c); const ab2 = orient(a, b, d); const cd1 = orient(c, d, a); const cd2 = orient(c, d, b);
  const eps = 1e-7;
  if ((ab1 > eps && ab2 < -eps || ab1 < -eps && ab2 > eps) && (cd1 > eps && cd2 < -eps || cd1 < -eps && cd2 > eps)) return true;
  return Math.abs(ab1) <= eps && onSegment(a, b, c) || Math.abs(ab2) <= eps && onSegment(a, b, d) || Math.abs(cd1) <= eps && onSegment(c, d, a) || Math.abs(cd2) <= eps && onSegment(c, d, b);
}
let geometryFailed = false;
for (const key of ['monza', 'spa', 'silverstone', 'nurburgring']) {
  const controlPoints = readPoints(key);
  if (process.env.TRACK_POINTS === '1') console.log(`${key} controls: ${controlPoints.map((p, i) => `${i}=(${(p.x / WORLD_SCALE).toFixed(0)},${(p.z / WORLD_SCALE).toFixed(0)})`).join(' ')}`);
  const duplicateControls = [];
  for (let i = 0; i < controlPoints.length; i++) for (let j = i + 1; j < controlPoints.length; j++) {
    const d = Math.hypot(controlPoints[i].x - controlPoints[j].x, controlPoints[i].z - controlPoints[j].z);
    if (d < ROAD_HALF_WIDTH * 2) duplicateControls.push(`${i}/${j}:${d.toFixed(1)}u`);
  }
  const curve = new THREE.CatmullRomCurve3(controlPoints, true, 'centripetal');
  curve.arcLengthDivisions = 2600;
  const samples = Array.from({ length: SAMPLE_COUNT }, (_, i) => curve.getPointAt(i / SAMPLE_COUNT));
  const minX = Math.min(...samples.map((p) => p.x)); const maxX = Math.max(...samples.map((p) => p.x)); const minZ = Math.min(...samples.map((p) => p.z)); const maxZ = Math.max(...samples.map((p) => p.z));
  const pad = 24; const sx = (760 - pad * 2) / Math.max(1, maxX - minX); const sz = (520 - pad * 2) / Math.max(1, maxZ - minZ); const s = Math.min(sx, sz);
  const polyline = samples.filter((_, i) => i % 2 === 0).map((p) => `${(pad + (p.x - minX) * s).toFixed(1)},${(520 - pad - (p.z - minZ) * s).toFixed(1)}`).join(' ');
  fs.writeFileSync(new URL(`./${key}-geometry.svg`, import.meta.url), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 760 520"><rect width="760" height="520" fill="#152018"/><polyline points="${polyline}" fill="none" stroke="#f3e8c8" stroke-width="12" stroke-linejoin="round" stroke-linecap="round"/><polyline points="${polyline}" fill="none" stroke="#343a3c" stroke-width="9" stroke-linejoin="round" stroke-linecap="round"/><text x="24" y="28" fill="#ff4d19" font-family="sans-serif" font-size="20">${key}</text></svg>`);
  let maxTurn = -Infinity; let sharpAt = -1;
  for (let i = 0; i < SAMPLE_COUNT; i++) {
    const a = samples[(i + SAMPLE_COUNT - 3) % SAMPLE_COUNT]; const b = samples[i]; const c = samples[(i + 3) % SAMPLE_COUNT];
    const ab = new THREE.Vector2(b.x - a.x, b.z - a.z).normalize(); const bc = new THREE.Vector2(c.x - b.x, c.z - b.z).normalize();
    const turn = Math.acos(THREE.MathUtils.clamp(ab.dot(bc), -1, 1)) * 180 / Math.PI;
    if (turn > maxTurn) { maxTurn = turn; sharpAt = i / SAMPLE_COUNT; }
  }
  let crossings = 0; let firstCross = ''; let closest = Infinity; let closestPair = ''; const ambiguousPairs = [];
  for (let i = 0; i < SAMPLE_COUNT; i += 2) {
    const a = samples[i]; const b = samples[(i + 1) % SAMPLE_COUNT];
    for (let j = i + MIN_SEPARATION_SAMPLES; j < SAMPLE_COUNT; j += 2) {
      const wrapGap = SAMPLE_COUNT - j + i;
      if (wrapGap < MIN_SEPARATION_SAMPLES) continue;
      const c = samples[j]; const d = samples[(j + 1) % SAMPLE_COUNT];
      if (segmentsCross(a, b, c, d)) { crossings++; if (!firstCross) firstCross = `${i}/${j}`; }
      const d1 = Math.hypot(a.x - c.x, a.z - c.z); const d2 = Math.hypot(a.x - d.x, a.z - d.z);
      const d3 = Math.hypot(b.x - c.x, b.z - c.z); const d4 = Math.hypot(b.x - d.x, b.z - d.z);
      const dmin = Math.min(d1, d2, d3, d4);
      if (dmin < closest) { closest = dmin; closestPair = `${i}/${j}`; }
      if (dmin < ROAD_HALF_WIDTH * 2 + 1.7) ambiguousPairs.push({ i, j, distance: dmin });
    }
  }
  const [ci, cj] = closestPair.split('/').map(Number); const cp = ci >= 0 ? samples[ci] : null; const cq = cj >= 0 ? samples[cj] : null;
  let narrowestHalf = ROAD_HALF_WIDTH;
  for (let i = 0; i < SAMPLE_COUNT; i += 2) {
    let nearest = Infinity;
    for (let j = 0; j < SAMPLE_COUNT; j += 2) { const gap = Math.min(Math.abs(i - j), SAMPLE_COUNT - Math.abs(i - j)); if (gap < MIN_SEPARATION_SAMPLES) continue; nearest = Math.min(nearest, Math.hypot(samples[i].x - samples[j].x, samples[i].z - samples[j].z)); }
    narrowestHalf = Math.min(narrowestHalf, Math.max(.65, (nearest - 1.6) * .46));
  }
  const tangentAt = (i) => new THREE.Vector2(samples[(i + 1) % SAMPLE_COUNT].x - samples[(i - 1 + SAMPLE_COUNT) % SAMPLE_COUNT].x, samples[(i + 1) % SAMPLE_COUNT].z - samples[(i - 1 + SAMPLE_COUNT) % SAMPLE_COUNT].z).normalize();
  const nearestControls = (v) => controlPoints.map((p, i) => ({ i, d: Math.hypot(p.x - v.x, p.z - v.z) })).sort((a, b) => a.d - b.d).slice(0, 4).map(({ i, d }) => `${i}:${d.toFixed(1)}`).join(',');
  const crossText = firstCross ? (() => { const [fi, fj] = firstCross.split('/').map(Number); const a = samples[fi]; const b = samples[fj]; const ta = tangentAt(fi); const tb = tangentAt(fj); const ua = curve.getUtoTmapping(fi / SAMPLE_COUNT) * controlPoints.length; const ub = curve.getUtoTmapping(fj / SAMPLE_COUNT) * controlPoints.length; return ` (${firstCross}) @ (${a.x.toFixed(1)},${a.z.toFixed(1)})↔(${b.x.toFixed(1)},${b.z.toFixed(1)}), tangents (${ta.x.toFixed(2)},${ta.y.toFixed(2)})/(${tb.x.toFixed(2)},${tb.y.toFixed(2)}), curve segments ${ua.toFixed(1)}/${ub.toFixed(1)}, nearest controls ${nearestControls(a)} / ${nearestControls(b)}`; })() : '';
  const closestText = cp ? `at (${cp.x.toFixed(1)},${cp.z.toFixed(1)}) ↔ (${cq.x.toFixed(1)},${cq.z.toFixed(1)}), curve segments ${(curve.getUtoTmapping(ci / SAMPLE_COUNT) * controlPoints.length).toFixed(1)}/${(curve.getUtoTmapping(cj / SAMPLE_COUNT) * controlPoints.length).toFixed(1)}, nearest controls ${nearestControls(cp)} / ${nearestControls(cq)}` : '';
  const worstPairs = ambiguousPairs.sort((a, b) => a.distance - b.distance).slice(0, 12).map(({ i, j, distance }) => `${i}/${j}:${distance.toFixed(1)}u`).join(' ');
  console.log(`${key}: max turn ${maxTurn.toFixed(2)}° @ t=${sharpAt.toFixed(3)}, centerline crossings=${crossings}${crossText}, nearest non-adjacent sample=${closest.toFixed(2)}u (${closestPair}) ${closestText}, effective road width ${(narrowestHalf * 2).toFixed(1)}–${(ROAD_HALF_WIDTH * 2).toFixed(1)}u, ambiguous sample pairs=${ambiguousPairs.length}${worstPairs ? ` [${worstPairs}]` : ''}, close controls ${duplicateControls.slice(0, 8).join(' ')}${duplicateControls.length > 8 ? ' …' : ''}`);
  if (crossings > 0 || ambiguousPairs.length > 0) geometryFailed = true;
}

if (geometryFailed) process.exitCode = 1;
