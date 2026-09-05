import * as THREE from 'three';
import { MTLLoader } from 'three/addons/loaders/MTLLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { TRACK_LAYOUTS } from './track-layouts.generated.js';
import './style.css';

const $ = (selector) => document.querySelector(selector);
const root = $('#game');
const speedEl = $('#speed');
const lapEl = $('#lap');
const timeEl = $('#time');
const bestTimeEl = $('#best-time');
const gearEl = $('#gear');
const rpmFill = $('#rpm-fill');
const rpmValueEl = $('#rpm-value');
const mapDot = $('#map-dot');
const statusEl = $('#status');
const wrongWayEl = $('#wrong-way');
const frontEnd = $('#front-end');
const raceUI = $('#race-ui');
const pauseOverlay = $('#pause-overlay');

// 赛道中心线来自 bacinger/f1-circuits 的真实 GeoJSON 轮廓，并离线转换成游戏坐标。
// 许可证与来源见 THIRD_PARTY_NOTICES.md；运行时不依赖网络请求。
const TRACKS = {
  monza: {
    name: '蒙扎', country: '意大利 · 蒙扎', distance: '5.793 KM', corners: '11 弯', number: '01', theme: '意大利林园',
    sky: 0xa9d5e2, fog: 0xa9d5e2, ground: 0x588a4f, curbA: 0xd22e27, curbB: 0xf2eee2,
    points: TRACK_LAYOUTS.monza,
    markers: [[.10,-1,150],[.12,-1,100],[.14,-1,50],[.70,1,100]],
  },
  spa: {
    name: '斯帕-弗朗科尔尚', country: '比利时 · 阿登', distance: '7.004 KM', corners: '19 弯', number: '02', theme: '阿登山林',
    sky: 0x98bbc5, fog: 0x98bbc5, ground: 0x3f7548, curbA: 0xd52d2b, curbB: 0xf0efe8,
    points: TRACK_LAYOUTS.spa,
    markers: [[.07,-1,100],[.09,-1,50],[.48,1,100],[.83,-1,100]],
  },
  silverstone: {
    name: '银石', country: '英国 · 北安普敦郡', distance: '5.890 KM', corners: '18 弯', number: '03', theme: '英国机场',
    sky: 0xb7c8ce, fog: 0xb7c8ce, ground: 0x617856, curbA: 0x2f678d, curbB: 0xf3eee1,
    points: TRACK_LAYOUTS.silverstone,
    markers: [[.12,1,100],[.34,-1,100],[.61,1,100],[.88,-1,100]],
  },
  nurburgring: {
    name: '纽博格林 GP', country: '德国 · 艾费尔', distance: '5.148 KM', corners: '15 弯', number: '04', theme: '艾费尔丘陵',
    sky: 0x9fb5b5, fog: 0x9fb5b5, ground: 0x466b45, curbA: 0xd52822, curbB: 0xf0eee5,
    points: TRACK_LAYOUTS.nurburgring,
    markers: [[.08,-1,100],[.31,1,100],[.56,-1,100],[.79,1,100]],
  },
};

// 车辆都来自公共 Kenney Car Kit；模型、菜单预览和性能参数由同一份配置驱动。
const CAR_OPTIONS = {
  clubsport: { name: 'KR-01 CLUBSPORT', model: 'sedan-sports.glb', preview: 'sedan-sports', topSpeedKmh: 302, launchAcceleration: 12.4 },
  gtcup: { name: 'KR-02 GT CUP', model: 'race.glb', preview: 'race', topSpeedKmh: 318, launchAcceleration: 13.6 },
  future: { name: 'KR-03 FUTURE GT', model: 'race-future.glb', preview: 'race-future', topSpeedKmh: 332, launchAcceleration: 14.7 },
  touring: { name: 'KR-04 TOURING', model: 'hatchback-sports.glb', preview: 'hatchback-sports', topSpeedKmh: 278, launchAcceleration: 11.2 },
};

let selectedTrackKey = 'monza';
let selectedTrack = TRACKS[selectedTrackKey];
let selectedCarKey = 'clubsport';
let activeCarSpec = CAR_OPTIONS[selectedCarKey];
let totalLaps = 3;
let assistMode = 0;
let paused = false;
let cameraMode = 1; // 默认近景第三人称；C 切换到远景
let trackCurve;
let trackLength = 1;
let trackSamples = [];
let trackTangents = [];
let trackHalfWidths = [];
let startP = new THREE.Vector3();
let startT = new THREE.Vector3(0, 0, 1);
let minimapProject = () => ({ x: 0, y: 0 });
// 采样密度和路宽按 GP 赛道标准提高，避免长直道和高速弯出现折线。
const sampleCount = 1040;
const trackWidth = 16.2;
// 源数据是归一化的真实中心线坐标；按每条赛道官方圈长反推米制比例，
// 让车长 4.35 m、赛道圈长和场景间距都与真实比例一致。
const TRACK_WORLD_SCALES = { monza: 5.0585, spa: 4.8424, silverstone: 4.0035, nurburgring: 3.5790 };
let worldScale = TRACK_WORLD_SCALES.monza;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.03, 4000);
const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
// 2x DPR + 2048 阴影在集成显卡上会明显拖慢帧率；1.5x 仍保持清晰，同时给车辆和场景留出 GPU 余量。
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.setSize(innerWidth, innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
root.appendChild(renderer.domElement);

scene.add(new THREE.HemisphereLight(0xe8f7ff, 0x40564a, 2.2));
const sun = new THREE.DirectionalLight(0xfff1cf, 3.5);
sun.position.set(-60, 90, 30); sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024);
sun.shadow.camera.left = -1100; sun.shadow.camera.right = 1100; sun.shadow.camera.top = 1100; sun.shadow.camera.bottom = -1100;
scene.add(sun);
function makeSurfaceTexture(baseHex, accentHex, size = 256, cell = 2) {
  const canvas = document.createElement('canvas'); canvas.width = size; canvas.height = size; const ctx = canvas.getContext('2d');
  const base = new THREE.Color(baseHex); const accent = new THREE.Color(accentHex); const image = ctx.createImageData(size, size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const gx = Math.floor(x / cell); const gy = Math.floor(y / cell);
    const n = (Math.sin(gx * 12.9898 + gy * 78.233 + baseHex) * 43758.5453) % 1;
    const amount = Math.abs(n) * .32; const color = base.clone().lerp(accent, amount);
    const i = (y * size + x) * 4; image.data[i] = color.r * 255; image.data[i + 1] = color.g * 255; image.data[i + 2] = color.b * 255; image.data[i + 3] = 255;
  }
  ctx.putImageData(image, 0, 0); const texture = new THREE.CanvasTexture(canvas); texture.wrapS = texture.wrapT = THREE.RepeatWrapping; texture.colorSpace = THREE.SRGBColorSpace; texture.anisotropy = renderer.capabilities.getMaxAnisotropy(); return texture;
}
const grassTexture = makeSurfaceTexture(0x4d6a43, 0x78915e, 512, 3); grassTexture.repeat.set(18, 18);
const asphaltTexture = makeSurfaceTexture(0x343a3c, 0x596062, 256, 2);
const groundMaterial = new THREE.MeshStandardMaterial({ color: selectedTrack.ground, map: grassTexture, roughness: 1 });
// 四条赛道按真实圈长重建后，蒙扎纵向范围超过 2 km；地面必须留出完整缓冲，避免边缘露底。
const ground = new THREE.Mesh(new THREE.PlaneGeometry(3600, 3600), groundMaterial);
ground.rotation.x = -Math.PI / 2; ground.position.y = -0.08; ground.receiveShadow = true; scene.add(ground);
let world = new THREE.Group(); world.matrixAutoUpdate = false; world.updateMatrix(); scene.add(world);
let worldGeneration = 0;
let sceneryClaims = [];

// Vite 的 BASE_URL 在本地为站点根目录，在 GitHub Pages 中为当前发布目录。
// 所有 public 资源都从这里派生，避免部署到 /Car/ 后仍错误请求站点根目录 /assets。
const publicBase = import.meta.env.BASE_URL;
const assetBase = `${publicBase}assets/kenney-selected/racing-kit/Models/OBJ%20format/`;
const roadsBase = `${publicBase}assets/kenney-selected/city-kit-roads/Models/OBJ%20format/`;
const industrialBase = `${publicBase}assets/kenney-selected/city-kit-industrial/Models/OBJ%20format/`;
const suburbanBase = `${publicBase}assets/kenney-selected/city-kit-suburban/Models/OBJ%20format/`;
const natureBase = `${publicBase}assets/kenney-selected/nature-kit/Models/OBJ%20format/`;
const kitTemplateCache = new Map();

function getKitTemplate(base, stem) {
  const key = `${base}${stem}`;
  if (!kitTemplateCache.has(key)) kitTemplateCache.set(key, new Promise((resolve, reject) => {
    const mtl = new MTLLoader(); mtl.setPath(base); mtl.load(`${stem}.mtl`, (materials) => {
      materials.preload(); const obj = new OBJLoader(); obj.setMaterials(materials); obj.setPath(base); obj.load(`${stem}.obj`, resolve, undefined, reject);
    }, undefined, reject);
  }));
  return kitTemplateCache.get(key);
}

function trackPose(t, sign = 1, offset = 0, advance = 0) {
  const p = trackCurve.getPointAt((t + 1) % 1); const tangent = trackCurve.getTangentAt((t + 1) % 1).normalize();
  const side = new THREE.Vector3(-tangent.z, 0, tangent.x).normalize();
  return { position: p.clone().addScaledVector(tangent, advance).addScaledVector(side, sign * offset), rotation: Math.atan2(tangent.x, tangent.z) };
}

function horizontalDistanceToTrack(position) {
  let best = Infinity;
  for (let i = 0; i < trackSamples.length; i += 2) { const p = trackSamples[i]; best = Math.min(best, Math.hypot(position.x - p.x, position.z - p.z)); }
  return best;
}

function buildTrackClearance() {
  const n = sampleCount; const clearances = new Float32Array(n + 1); const minSeparationSamples = 24;
  for (let i = 0; i < n; i += 2) {
    let nearest = Infinity;
    for (let j = 0; j < n; j += 2) {
      const gap = Math.abs(i - j); const cyclicGap = Math.min(gap, n - gap);
      if (cyclicGap < minSeparationSamples) continue;
      const a = trackSamples[i]; const b = trackSamples[j]; nearest = Math.min(nearest, Math.hypot(a.x - b.x, a.z - b.z));
    }
    clearances[i] = nearest;
  }
  for (let i = 1; i < n; i++) clearances[i] = clearances[i - 1] || clearances[i + 1] || trackWidth;
  clearances[n] = clearances[0];
  // 正常段保持全宽；只有回叠段收窄到不与相邻柏油带相交，避免视觉穿模。
  trackHalfWidths = Array.from(clearances, (distance) => Math.min(trackWidth / 2, Math.max(.65, (distance - 1.6) * .46)));
}

// 仅用于 HUD 和净空检查的轻量采样，避免每帧重新执行 CatmullRomCurve3.getPointAt。
function sampleTrackPoint(t) {
  if (!trackSamples.length) return trackCurve.getPointAt(t);
  const wrapped = ((t % 1) + 1) % 1;
  const scaled = wrapped * sampleCount;
  const index = Math.floor(scaled);
  const alpha = scaled - index;
  const a = trackSamples[index];
  const b = trackSamples[Math.min(sampleCount, index + 1)];
  return new THREE.Vector3().lerpVectors(a, b, alpha);
}

function loadKitOnTrack(base, stem, size, t, sign, offset, rotationOffset = 0, advance = 0, generation = worldGeneration) {
  // 用模型最大边长的保守半径做净空，而不是只按中心点摆放，避免长建筑/树干切进柏油或彼此穿插。
  const radius = Math.max(3.5, size * .94); let resolvedOffset = Math.max(offset, trackWidth / 2 + radius + 6); let pose = trackPose(t, sign, resolvedOffset, advance);
  const safeDistance = trackWidth / 2 + radius + 6; let attempts = 0;
  const overlapsClaim = () => sceneryClaims.some((claim) => Math.hypot(claim.x - pose.position.x, claim.z - pose.position.z) < claim.radius + radius + 2);
  while ((horizontalDistanceToTrack(pose.position) < safeDistance || overlapsClaim()) && attempts++ < 20) { resolvedOffset += 6; pose = trackPose(t, sign, resolvedOffset, advance); }
  // 回头弯/交叉段可能始终没有足够的外侧净空；宁可不放置，也不让设施落到柏油上。
  if (horizontalDistanceToTrack(pose.position) < safeDistance || overlapsClaim()) { console.warn(`[asset] skipped no-clearance: ${stem}`); return Promise.resolve(); }
  sceneryClaims.push({ x: pose.position.x, z: pose.position.z, radius });
  return getKitTemplate(base, stem).then((template) => {
    if (generation !== worldGeneration) return;
    const model = template.clone(true); const rawBox = new THREE.Box3().setFromObject(model); const rawSize = rawBox.getSize(new THREE.Vector3());
    model.scale.setScalar(size / Math.max(rawSize.x, rawSize.y, rawSize.z)); model.rotation.y = pose.rotation + rotationOffset; model.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(model); const center = box.getCenter(new THREE.Vector3());
    const actualRadius = Math.max(2.5, Math.hypot(box.max.x - box.min.x, box.max.z - box.min.z) * .5);
    // 资源包里有些建筑的原点偏在边缘；模型最终会以包围盒中心对齐 pose，按最终落点再做一次赛道净空校验。
    const placedCenter = new THREE.Vector3(pose.position.x, pose.position.y, pose.position.z);
    if (horizontalDistanceToTrack(placedCenter) < trackWidth / 2 + actualRadius + 1.5) { console.warn(`[asset] skipped near asphalt: ${stem}`); return; }
    model.position.set(pose.position.x - center.x, pose.position.y - box.min.y, pose.position.z - center.z);
    model.updateMatrix(); model.matrixAutoUpdate = false;
    model.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } }); world.add(model);
  }).catch((error) => console.warn(`[asset] ${stem}`, error));
}

function meshFromStrip(positions, indices, material, uvs = null) {
  const geometry = new THREE.BufferGeometry(); geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3)); geometry.setIndex(indices); geometry.computeVertexNormals();
  if (uvs) geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  const mesh = new THREE.Mesh(geometry, material); mesh.receiveShadow = true; mesh.matrixAutoUpdate = false; mesh.updateMatrix(); world.add(mesh); return mesh;
}

function addBrakeMarker(t, sign, number) {
  const pose = trackPose(t, sign, trackWidth / 2 + 3.3);
  if (horizontalDistanceToTrack(pose.position) < trackWidth / 2 + 1.0) return;
  const group = new THREE.Group();
  const post = new THREE.Mesh(new THREE.BoxGeometry(.11, 2.15, .11), new THREE.MeshStandardMaterial({ color: 0xd3d5d6 })); post.position.y = 1.07;
  const label = document.createElement('canvas'); label.width = 128; label.height = 80; const ctx = label.getContext('2d');
  ctx.fillStyle = '#f5f1e7'; ctx.fillRect(0, 0, 128, 80); ctx.fillStyle = '#171a1d'; ctx.font = 'bold 45px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(String(number), 64, 42);
  const board = new THREE.Mesh(new THREE.BoxGeometry(1.05, .68, .08), new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(label) })); board.position.y = 1.78;
  group.add(post, board); group.position.copy(pose.position); group.rotation.y = pose.rotation; world.add(group);
}

function addSectionLabel(t, sign, text) {
  const pose = trackPose(t, sign, trackWidth / 2 + 5.2);
  if (horizontalDistanceToTrack(pose.position) < trackWidth / 2 + 1.8) return;
  const group = new THREE.Group();
  sceneryClaims.push({ x: pose.position.x, z: pose.position.z, radius: 2.6 });
  const postMat = new THREE.MeshStandardMaterial({ color: 0x555c61, roughness: .82 });
  const post = new THREE.Mesh(new THREE.BoxGeometry(.12, 2.6, .12), postMat); post.position.y = 1.3;
  const canvas = document.createElement('canvas'); canvas.width = 320; canvas.height = 68; const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#11171b'; ctx.fillRect(0, 0, canvas.width, canvas.height); ctx.fillStyle = '#ff5423'; ctx.fillRect(0, 0, 9, canvas.height);
  ctx.fillStyle = '#f4f2e9'; ctx.font = '800 27px Arial'; ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillText(text, 23, 36);
  const board = new THREE.Mesh(new THREE.BoxGeometry(3.15, .68, .08), new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(canvas), side: THREE.DoubleSide }));
  board.position.y = 2.36; group.add(post, board); group.position.copy(pose.position); group.rotation.y = pose.rotation; world.add(group);
}

function buildMinimap() {
  const samples = Array.from({ length: 180 }, (_, i) => sampleTrackPoint(i / 180));
  const minX = Math.min(...samples.map((p) => p.x)); const maxX = Math.max(...samples.map((p) => p.x)); const minZ = Math.min(...samples.map((p) => p.z)); const maxZ = Math.max(...samples.map((p) => p.z));
  const scale = Math.min(184 / (maxX - minX), 105 / (maxZ - minZ));
  minimapProject = (p) => ({ x: 110 + (p.x - (minX + maxX) / 2) * scale, y: 67.5 + (p.z - (minZ + maxZ) / 2) * scale });
  const d = samples.map((p, i) => { const q = minimapProject(p); return `${i ? 'L' : 'M'}${q.x.toFixed(1)} ${q.y.toFixed(1)}`; }).join(' ') + ' Z';
  $('.map-shadow').setAttribute('d', d); $('.map-line').setAttribute('d', d); const first = minimapProject(samples[0]); mapDot.setAttribute('cx', first.x); mapDot.setAttribute('cy', first.y);
  $('#hud-track-number').textContent = selectedTrack.number; $('#hud-track-name').textContent = selectedTrack.name; $('#hud-track-distance').textContent = selectedTrack.distance; $('#ready-track').textContent = selectedTrack.name;
}

// 开始界面与比赛 HUD 共用同一套中心线数据，避免手工 SVG 轮廓与实际路线不一致。
function updateCircuitIcons() {
  document.querySelectorAll('.circuit-card[data-track]').forEach((card) => {
    const path = card.querySelector('.circuit-art svg path'); const layout = TRACKS[card.dataset.track]?.points;
    if (!path || !layout?.length) return;
    const curve = new THREE.CatmullRomCurve3(layout.map(([x, z]) => new THREE.Vector3(x, 0, z)), true, 'centripetal'); curve.arcLengthDivisions = 1200;
    const samples = Array.from({ length: 180 }, (_, i) => curve.getPointAt(i / 180));
    const minX = Math.min(...samples.map((point) => point.x)); const maxX = Math.max(...samples.map((point) => point.x));
    const minZ = Math.min(...samples.map((point) => point.z)); const maxZ = Math.max(...samples.map((point) => point.z));
    const paddingX = 14; const paddingY = 12; const scale = Math.min((180 - paddingX * 2) / Math.max(1, maxX - minX), (100 - paddingY * 2) / Math.max(1, maxZ - minZ));
    const centerX = (minX + maxX) * .5; const centerZ = (minZ + maxZ) * .5;
    const d = samples.map((point, index) => {
      const x = 90 + (point.x - centerX) * scale; const y = 50 + (point.z - centerZ) * scale;
      return `${index ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`;
    }).join(' ') + ' Z';
    path.setAttribute('d', d);
  });
}

function addRouteGuides() {
  // 用少量 InstancedMesh 箭头明确赛道行驶方向；箭头贴在柏油表面并放在车道一侧，避免遮住车辆。
  const shape = new THREE.Shape();
  shape.moveTo(0, 2.4); shape.lineTo(1.55, .55); shape.lineTo(.68, .55); shape.lineTo(.68, -1.35);
  shape.lineTo(-.68, -1.35); shape.lineTo(-.68, .55); shape.lineTo(-1.55, .55); shape.closePath();
  const geometry = new THREE.ShapeGeometry(shape); geometry.rotateX(Math.PI / 2);
  // ShapeGeometry 的法线在铺到地面后朝下；双面材质确保从驾驶视角能看到方向箭头。
  const material = new THREE.MeshBasicMaterial({ color: 0x46ddff, transparent: true, opacity: .82, depthTest: true, depthWrite: false, side: THREE.DoubleSide, polygonOffset: true, polygonOffsetFactor: -2 });
  const samples = [];
  // 从起步线前方留出约 80 m 视距，箭头间距约 130 m（按真实圈长），车身附近保持干净。
  for (let i = 14; i < sampleCount; i += 24) samples.push(i);
  const arrows = new THREE.InstancedMesh(geometry, material, samples.length);
  arrows.instanceMatrix.setUsage(THREE.StaticDrawUsage); arrows.matrixAutoUpdate = false; arrows.updateMatrix(); arrows.frustumCulled = false;
  const dummy = new THREE.Object3D();
  samples.forEach((sampleIndex, instanceIndex) => {
    const p = trackSamples[sampleIndex]; const tangent = trackTangents[sampleIndex]; const side = new THREE.Vector3(-tangent.z, 0, tangent.x).normalize();
    dummy.position.copy(p).addScaledVector(side, -3.8); dummy.position.y += .055; dummy.scale.setScalar(.96);
    dummy.rotation.set(0, Math.atan2(tangent.x, tangent.z), 0); dummy.updateMatrix(); arrows.setMatrixAt(instanceIndex, dummy.matrix);
  });
  arrows.instanceMatrix.needsUpdate = true; arrows.renderOrder = 1; world.add(arrows);
}

function buildWorld(key) {
  selectedTrackKey = key; selectedTrack = TRACKS[key]; worldGeneration++;
  scene.remove(world); world = new THREE.Group(); world.matrixAutoUpdate = false; world.updateMatrix(); scene.add(world); sceneryClaims = [];
  worldScale = TRACK_WORLD_SCALES[key] || TRACK_WORLD_SCALES.monza;
  scene.background = new THREE.Color(selectedTrack.sky); scene.fog = new THREE.Fog(selectedTrack.fog, 320, 3000); groundMaterial.color.setHex(selectedTrack.ground);
  const minElevation = Math.min(...selectedTrack.points.map((point) => point[2]));
  // 生成数据已按弧长均匀采样并通过离线净距检查，不再使用旧的控制点排斥算法扭曲真实轮廓。
  const vectors = selectedTrack.points.map(([x, z, y]) => new THREE.Vector3(x * worldScale, (y - minElevation) * .52, z * worldScale));
  trackCurve = new THREE.CatmullRomCurve3(vectors, true, 'centripetal'); trackCurve.arcLengthDivisions = 2600; trackLength = trackCurve.getLength();
  // 建图时一次性缓存中心线和切线。运行时最近点查询与道路网格都复用它们。
  trackSamples = Array.from({ length: sampleCount + 1 }, (_, i) => trackCurve.getPointAt(i / sampleCount));
  trackTangents = Array.from({ length: sampleCount + 1 }, (_, i) => trackCurve.getTangentAt(i / sampleCount).normalize());
  buildTrackClearance();
  startP = trackSamples[0]; startT = trackTangents[0];

  const roadPositions = []; const roadUvs = []; const shoulderPositions = []; const indices = [];
  for (let i = 0; i <= sampleCount; i++) {
    const t = i / sampleCount; const p = trackSamples[i]; const tangent = trackTangents[i]; const side = new THREE.Vector3(-tangent.z, 0, tangent.x).normalize();
    const localHalfWidth = trackHalfWidths[i] || trackWidth / 2;
    const left = p.clone().addScaledVector(side, localHalfWidth); const right = p.clone().addScaledVector(side, -localHalfWidth);
    const shoulderLeft = p.clone().addScaledVector(side, localHalfWidth + .85); const shoulderRight = p.clone().addScaledVector(side, -localHalfWidth - .85);
    roadPositions.push(left.x, left.y + .07, left.z, right.x, right.y + .07, right.z);
    shoulderPositions.push(shoulderLeft.x, shoulderLeft.y + .015, shoulderLeft.z, shoulderRight.x, shoulderRight.y + .015, shoulderRight.z);
    const repeat = t * Math.max(18, trackLength / 32); roadUvs.push(0, repeat, 1, repeat);
    if (i < sampleCount) { const n = i + 1; indices.push(i * 2, i * 2 + 1, n * 2, i * 2 + 1, n * 2 + 1, n * 2); }
  }
  meshFromStrip(shoulderPositions, indices, new THREE.MeshStandardMaterial({ color: 0xc9c3aa, roughness: 1, side: THREE.DoubleSide }));
  // Kenney PNG/Default 是 64px 的道路图块（带绿色边框），直接铺满赛道会产生糊边和错误色带。
  // 这里保留 Road Textures 包作为来源，运行时生成高分辨率柏油微表面，且在不同赛道间复用同一张纹理。
  meshFromStrip(roadPositions, indices, new THREE.MeshStandardMaterial({ color: 0xdfe3e2, map: asphaltTexture, roughness: .94, side: THREE.DoubleSide }), roadUvs);
  addRouteGuides();

  const startLine = new THREE.Mesh(new THREE.BoxGeometry(trackWidth, .035, .85), new THREE.MeshStandardMaterial({ color: 0xf7f0d0 }));
  startLine.position.copy(startP); startLine.position.y += .115; startLine.rotation.y = Math.atan2(startT.x, startT.z); world.add(startLine);
  const lineMat = new THREE.MeshBasicMaterial({ color: 0xf6f1df });
  const curbMats = [new THREE.MeshStandardMaterial({ color: selectedTrack.curbA }), new THREE.MeshStandardMaterial({ color: selectedTrack.curbB })];
  // 路缘和中心虚线原先每块都是独立 Mesh（约 520 次 draw call）；改用 InstancedMesh，保持细节但显著降低卡顿。
  const dashCount = Math.ceil((sampleCount - 1) / 6);
  const dashMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(.12, .025, 2), lineMat, dashCount);
  dashMesh.instanceMatrix.setUsage(THREE.StaticDrawUsage); dashMesh.receiveShadow = false; dashMesh.castShadow = false; dashMesh.matrixAutoUpdate = false; dashMesh.updateMatrix();
  const curbCounts = [0, 0];
  for (let i = 1; i < sampleCount; i += 6) curbCounts[(i / 6) % 2 | 0] += 2;
  const curbMeshes = curbCounts.map((count, materialIndex) => {
    const mesh = new THREE.InstancedMesh(new THREE.BoxGeometry(.52, .065, .9), curbMats[materialIndex], count);
    mesh.instanceMatrix.setUsage(THREE.StaticDrawUsage); mesh.castShadow = false; mesh.receiveShadow = true; mesh.matrixAutoUpdate = false; mesh.updateMatrix(); mesh.frustumCulled = false; world.add(mesh); return mesh;
  });
  const dummy = new THREE.Object3D(); const curbOffsets = [0, 0]; let dashIndex = 0;
  for (let i = 1; i < sampleCount; i += 6) {
    const p = trackSamples[i]; const tan = trackTangents[i]; const rot = Math.atan2(tan.x, tan.z); const side = new THREE.Vector3(-tan.z, 0, tan.x).normalize(); const localHalfWidth = trackHalfWidths[i] || trackWidth / 2;
    dummy.position.copy(p); dummy.position.y += .115; dummy.rotation.set(0, rot, 0); dummy.updateMatrix(); dashMesh.setMatrixAt(dashIndex++, dummy.matrix);
    const materialIndex = (i / 6) % 2 | 0;
    for (const sign of [-1, 1]) {
      dummy.position.copy(p).addScaledVector(side, sign * (localHalfWidth + .38)); dummy.position.y += .105; dummy.rotation.set(0, rot, 0); dummy.updateMatrix();
      curbMeshes[materialIndex].setMatrixAt(curbOffsets[materialIndex]++, dummy.matrix);
    }
  }
  dashMesh.instanceMatrix.needsUpdate = true; dashMesh.frustumCulled = false; world.add(dashMesh);
  selectedTrack.markers.forEach((entry) => addBrakeMarker(...entry));
  const sectionLabels = {
    monza: [['RETTIFILO', .075, 1], ['LESMO', .31, -1], ['ASCARI', .61, 1], ['PARABOLICA', .89, -1]],
    spa: [['LA SOURCE', .04, 1], ['EAU ROUGE', .19, -1], ['KEMMEL', .34, 1], ['POUHON', .55, -1], ['BLANCHIMONT', .79, 1], ['BUS STOP', .94, -1]],
    silverstone: [['ABBEY', .03, 1], ['VILLAGE', .18, -1], ['COPSE', .38, 1], ['MAGGOTTS', .59, -1], ['STOWE', .76, 1], ['CLUB', .93, -1]],
    nurburgring: [['ARENA', .04, 1], ['DUNLOP', .24, -1], ['SCHUMACHER', .45, 1], ['VEEDOL', .68, -1], ['COCA-COLA', .9, 1]],
  }[key];
  sectionLabels.forEach(([label, t, sign]) => addSectionLabel(t, sign, label));

  // 所有实体设施只生成在路肩安全区以外，柏油路面保持完全净空。
  // 不铺设会被误认为“岔路”的大块灰色板；起步区只保留柏油、标线和安全的赛道设施。
  const generation = worldGeneration;
  loadKitOnTrack(assetBase, 'grandStandCovered', 20, .025, 1, 40, 0, 3, generation);
  loadKitOnTrack(assetBase, 'pitsGarage', 20, .035, -1, 42, 0, 2, generation);
  loadKitOnTrack(assetBase, 'pitsOffice', 14, .12, -1, 38, 0, 0, generation);
  loadKitOnTrack(assetBase, 'bannerTowerRed', 8, .10, 1, 24, 0, 0, generation);
  loadKitOnTrack(assetBase, 'bannerTowerGreen', 8, .16, -1, 24, 0, 0, generation);
  for (const [t, sign] of [[.18,1],[.34,-1],[.51,1],[.69,-1],[.84,1],[.96,-1]]) loadKitOnTrack(assetBase, 'billboardLow', 5.5, t, sign, 15, Math.PI / 2, 0, generation);
  for (const [t, sign] of [[.08,1],[.23,-1],[.42,1],[.62,-1],[.78,1],[.93,-1]]) loadKitOnTrack(assetBase, 'lightPostModern', 7.5, t, sign, 13, 0, 0, generation);

  const themeLandmarks = {
    monza: [[suburbanBase,'building-type-c',13,.42,1,31],[industrialBase,'water-tower',14,.68,-1,34]],
    spa: [[suburbanBase,'building-type-g',13,.16,-1,30],[roadsBase,'bridge-pillar-wide',9,.56,1,22]],
    silverstone: [[industrialBase,'building-a',19,.31,-1,33],[industrialBase,'building-f',17,.35,-1,34]],
    nurburgring: [[suburbanBase,'building-type-a',13,.24,1,31],[industrialBase,'water-tower',14,.76,-1,34]],
  }[key];
  themeLandmarks.forEach(([base, stem, size, t, sign, offset]) => loadKitOnTrack(base, stem, size, t, sign, offset, 0, 0, generation));
  const natureStems = ['tree_pineTallA_detailed','tree_pineTallB_detailed','tree_pineRoundA','tree_oak','tree_detailed'];
  for (let i = 0; i < 48; i++) {
    const t = (i * .037 + .11) % 1; const sign = i % 2 ? 1 : -1; const offset = 23 + (i % 4) * 6;
    loadKitOnTrack(natureBase, natureStems[i % natureStems.length], 8 + (i % 3), t, sign, offset, i * .47, (i % 3) * 3, generation);
  }
  const mountainColors = key === 'silverstone' ? [0x75847f,0x687873] : [0x557276,0x3f5c60,0x31484d];
  const mapRadius = Math.max(...trackSamples.map((point) => Math.hypot(point.x, point.z)));
  // 山体跟随真实地图外扩，避免放大赛道后山锥切进道路视线形成“巨型岔路/挡板”。
  const mountainRadius = mapRadius + 430;
  for (let i = 0; i < (key === 'silverstone' ? 8 : 20); i++) {
    const mountain = new THREE.Mesh(new THREE.ConeGeometry(28 + (i % 3) * 12, 34 + (i % 4) * 10, 5), new THREE.MeshBasicMaterial({ color: mountainColors[i % mountainColors.length] }));
    const angle = (i / 20) * Math.PI * 2; const radius = mountainRadius + (i % 2) * 55; mountain.position.set(Math.cos(angle) * radius, 12, Math.sin(angle) * radius); mountain.rotation.y = i * .73; world.add(mountain);
  }
  buildMinimap(); if (car) resetCar();
  console.info(`[track] ${selectedTrack.name}`, { length: trackLength.toFixed(1), clearance: 'asphalt clear' });
}

let car = new THREE.Group(); scene.add(car);
let playerCarModel = null;
let carLoadGeneration = 0;
// 车内视角使用一组轻量的座舱几何，不依赖车辆模型必须自带内饰；外部车身在该视角自动隐藏。
const cockpit = new THREE.Group(); cockpit.visible = false; car.add(cockpit);
const cockpitDashMat = new THREE.MeshStandardMaterial({ color: 0x101419, roughness: .82, metalness: .08 });
const cockpitTrimMat = new THREE.MeshStandardMaterial({ color: 0x343b43, roughness: .56, metalness: .35 });
const cockpitGlassMat = new THREE.MeshBasicMaterial({ color: 0x9fc4d2, transparent: true, opacity: .10, side: THREE.DoubleSide, depthWrite: false });
const dashboard = new THREE.Mesh(new THREE.BoxGeometry(2.65, .22, .64), cockpitDashMat); dashboard.position.set(0, .84, .73); cockpit.add(dashboard);
const dashTop = new THREE.Mesh(new THREE.BoxGeometry(1.22, .06, .12), cockpitTrimMat); dashTop.position.set(0, .985, .48); cockpit.add(dashTop);
const steeringWheel = new THREE.Mesh(new THREE.TorusGeometry(.235, .045, 8, 18), cockpitTrimMat); steeringWheel.position.set(0, 1.08, .24); cockpit.add(steeringWheel);
const steeringHub = new THREE.Mesh(new THREE.CylinderGeometry(.055, .055, .07, 8), cockpitTrimMat); steeringHub.rotation.x = Math.PI / 2; steeringHub.position.set(0, 1.08, .24); cockpit.add(steeringHub);
for (const x of [-1.08, 1.08]) {
  const pillar = new THREE.Mesh(new THREE.BoxGeometry(.10, 1.04, .12), cockpitTrimMat); pillar.position.set(x, 1.38, .98); pillar.rotation.z = x < 0 ? -.13 : .13; cockpit.add(pillar);
}
const windshield = new THREE.Mesh(new THREE.PlaneGeometry(2.08, .72), cockpitGlassMat); windshield.position.set(0, 1.42, 1.02); cockpit.add(windshield);
const headLampMat = new THREE.MeshBasicMaterial({ color: 0xfff5d0 }); const tailLampMat = new THREE.MeshBasicMaterial({ color: 0xf22a1d });
for (const x of [-.78, .78]) {
  const head = new THREE.Mesh(new THREE.BoxGeometry(.22, .1, .06), headLampMat); head.position.set(x, .7, 2.08); car.add(head);
  const tail = new THREE.Mesh(new THREE.BoxGeometry(.24, .11, .06), tailLampMat); tail.position.set(x, .7, -2.08); car.add(tail);
}
const headGlow = new THREE.PointLight(0xffe5bd, 1.15, 10); headGlow.position.set(0, .62, 2.25); car.add(headGlow);
function fitPlayerCar(model, targetLength = 4.35) {
  const rawBox = new THREE.Box3().setFromObject(model); const rawSize = rawBox.getSize(new THREE.Vector3()); model.scale.setScalar(targetLength / rawSize.z); model.updateMatrixWorld(true);
  const scaledBox = new THREE.Box3().setFromObject(model); model.position.y = -scaledBox.min.y; model.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } }); playerCarModel = model; car.add(model);
}
const carLoader = new GLTFLoader();
const carModelBase = `${publicBase}assets/kenney-selected/car-kit/Models/GLB%20format/`;
const fallbackCarLoader = new GLTFLoader();
fallbackCarLoader.setPath(carModelBase);
function clearPlayerCarModel() {
  if (!playerCarModel) return;
  car.remove(playerCarModel); playerCarModel = null;
}
function applyCarSpec(key) {
  activeCarSpec = CAR_OPTIONS[key] || CAR_OPTIONS.clubsport;
  maxSpeed = activeCarSpec.topSpeedKmh / SPEED_TO_KMH;
  launchAcceleration = activeCarSpec.launchAcceleration;
  const readyCar = $('#ready-car'); if (readyCar) readyCar.textContent = activeCarSpec.name;
}
function loadSelectedCar() {
  const spec = activeCarSpec; const generation = ++carLoadGeneration;
  clearPlayerCarModel();
  carLoader.load(`${carModelBase}${spec.model}`, (gltf) => {
    if (generation !== carLoadGeneration) return;
    fitPlayerCar(gltf.scene, 4.35);
  }, undefined, () => {
    if (generation !== carLoadGeneration || spec.model === 'sedan-sports.glb') return;
    fallbackCarLoader.load('sedan-sports.glb', (gltf) => { if (generation === carLoadGeneration) fitPlayerCar(gltf.scene, 4.35); });
  });
}

let started = false; let finished = false; let countdownActive = false; let countdownTimer = null; let elapsed = 0; let lap = 0; let speed = 0; let heading = 0; let lastProgress = 0; let lastTime = performance.now(); let hudAccumulator = 0; let wrongWayTime = 0;
let velocity = new THREE.Vector3(); let yawRate = 0;
const bestTimes = new Map();
// 速度单位标定：1 world unit 对应 1 m；当前 3.2 km/h·unit⁻¹，
// 让 200 km/h 对应约 62.5 m/s 的实际位移，最高速约 302 km/h。
const SPEED_TO_KMH = 3.2;
let maxSpeed = activeCarSpec.topSpeedKmh / SPEED_TO_KMH;
const reverseMaxSpeed = 6.0;
// 起步加速度按 GT 赛车重新标定：不同车型有不同的低速扭矩和最高速。
let launchAcceleration = activeCarSpec.launchAcceleration;
const launchTorqueBoost = 1.2;
const reverseAcceleration = 3.8;
const brakeDeceleration = 17.5;
const keys = new Set();
const FIXED_DT = 1 / 60; const MAX_PHYSICS_STEPS = 5; let physicsAccumulator = 0;
const INPUT_BINDINGS = { throttle: ['KeyW','ArrowUp'], brake: ['KeyS','ArrowDown'], steerLeft: ['KeyA','ArrowLeft'], steerRight: ['KeyD','ArrowRight'] };
const actionHeld = (action) => INPUT_BINDINGS[action].some((code) => keys.has(code));
// 自动变速箱：换挡使用迟滞阈值，避免在临界速度附近来回跳档。
const GEAR_RATIOS = [0, 3.18, 2.12, 1.52, 1.18, .94, .76];
const GEAR_UP_KMH = [0, 62, 101, 142, 184, 226, 999];
const GEAR_DOWN_KMH = [0, 0, 44, 74, 110, 151, 194];
const GEAR_DRIVE_FORCE = [1, 1, .90, .82, .75, .69, .63];
let currentGear = 0;
let engineRpm = 950;
let previousThrottle = false;
let throttleInput = 0;
let brakeInput = 0;
let nextShiftAllowedAt = 0;
let lastShiftElapsed = -99;
function nearestTrackInfo(pos) {
  let best = { dist: Infinity, t: 0, point: startP, tangent: startT, index: 0 };
  for (let i = 0; i < sampleCount; i += 2) { const t = i / sampleCount; const p = trackSamples[i]; const d = Math.hypot(p.x - pos.x, p.z - pos.z); if (d < best.dist) best = { dist: d, t, point: p, tangent: trackTangents[i], index: i }; }
  return best;
}
function formatTime(v) { const m = Math.floor(v / 60); const s = (v % 60).toFixed(3).padStart(6, '0'); return `${String(m).padStart(2, '0')}:${s}`; }
function resetCar(toNearest = false) {
  let targetPoint = startP; let targetTangent = startT;
  let resetProgress = 0;
  if (toNearest && trackSamples.length) {
    const nearest = nearestTrackInfo(car.position);
    targetPoint = nearest.point;
    targetTangent = trackTangents[Math.min(sampleCount, Math.round(nearest.t * sampleCount))] || startT;
    resetProgress = nearest.t;
  }
  car.position.copy(targetPoint); car.position.y += .14; heading = Math.atan2(targetTangent.x, targetTangent.z); car.rotation.y = heading; speed = 0; velocity.set(0, 0, 0); yawRate = 0; lastProgress = resetProgress; currentGear = 0; engineRpm = 950; previousThrottle = false; throttleInput = 0; brakeInput = 0; nextShiftAllowedAt = elapsed; lastShiftElapsed = -99; physicsAccumulator = 0; hudAccumulator = 0; wrongWayTime = 0; wrongWayEl.classList.add('hidden');
}

let engineAudio;
function startEngineAudio() {
  if (engineAudio) { void engineAudio.ctx.resume(); return; }
  try {
  const AudioCtor = window.AudioContext || window.webkitAudioContext;
  if (!AudioCtor) return;
  const ctx = new AudioCtor();
  const master = ctx.createGain(); master.gain.value = .0001;
  const compressor = ctx.createDynamicsCompressor(); compressor.threshold.value = -17; compressor.knee.value = 16; compressor.ratio.value = 4; compressor.attack.value = .004; compressor.release.value = .16;
  const mixBus = ctx.createGain(); mixBus.gain.value = .92; mixBus.connect(compressor).connect(master).connect(ctx.destination);
  const engineBus = ctx.createGain(); engineBus.gain.value = .8;
  const exhaustBus = ctx.createGain(); exhaustBus.gain.value = .7;
  const mechanicalBus = ctx.createGain(); mechanicalBus.gain.value = .45;
  const windBus = ctx.createGain(); windBus.gain.value = .35;
  const engineResonance = ctx.createBiquadFilter(); engineResonance.type = 'peaking'; engineResonance.frequency.value = 820; engineResonance.Q.value = 1.1; engineResonance.gain.value = 5;
  const warmth = ctx.createWaveShaper(); const warmthCurve = new Float32Array(257); for (let i = 0; i < warmthCurve.length; i++) { const x = i * 2 / (warmthCurve.length - 1) - 1; warmthCurve[i] = Math.tanh(x * 1.7); } warmth.curve = warmthCurve; warmth.oversample = '2x';
  engineBus.connect(engineResonance).connect(warmth).connect(mixBus);
  const exhaustFilter = ctx.createBiquadFilter(); exhaustFilter.type = 'lowpass'; exhaustFilter.frequency.value = 1300; exhaustFilter.Q.value = .7; exhaustBus.connect(exhaustFilter).connect(mixBus);
  mechanicalBus.connect(mixBus); windBus.connect(mixBus);

  // 四缸四冲程的点火基频：rpm / 60 * 2，再用谐波与共振峰塑造发动机音色。
  const pulse = ctx.createOscillator(); pulse.type = 'sawtooth'; const pulseGain = ctx.createGain(); pulseGain.gain.value = .48; pulse.connect(pulseGain).connect(engineBus); pulse.start();
  const body = ctx.createOscillator(); body.type = 'triangle'; const bodyGain = ctx.createGain(); bodyGain.gain.value = .62; body.connect(bodyGain).connect(engineBus); body.start();
  const harmonics = ctx.createOscillator(); harmonics.type = 'square'; const harmonicGain = ctx.createGain(); harmonicGain.gain.value = .14; harmonics.connect(harmonicGain).connect(engineBus); harmonics.start();
  const intake = ctx.createOscillator(); intake.type = 'sine'; const intakeGain = ctx.createGain(); intakeGain.gain.value = .16; intake.connect(intakeGain).connect(engineBus); intake.start();
  const exhaust = ctx.createOscillator(); exhaust.type = 'sawtooth'; const exhaustGain = ctx.createGain(); exhaustGain.gain.value = .18; exhaust.connect(exhaustGain).connect(exhaustBus); exhaust.start();
  const mechanical = ctx.createOscillator(); mechanical.type = 'square'; const mechanicalGain = ctx.createGain(); mechanicalGain.gain.value = .035; mechanical.connect(mechanicalGain).connect(mechanicalBus); mechanical.start();
  const limiter = ctx.createOscillator(); limiter.type = 'square'; const limiterGain = ctx.createGain(); limiterGain.gain.value = 0; limiter.connect(limiterGain).connect(mechanicalBus); limiter.start();
  const gearWhine = ctx.createOscillator(); gearWhine.type = 'triangle'; const gearWhineFilter = ctx.createBiquadFilter(); gearWhineFilter.type = 'highpass'; gearWhineFilter.frequency.value = 260; const gearWhineGain = ctx.createGain(); gearWhineGain.gain.value = 0; gearWhine.connect(gearWhineFilter).connect(gearWhineGain).connect(mechanicalBus); gearWhine.start();

  const noiseBuffer = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate); const noiseData = noiseBuffer.getChannelData(0); let seed = 1337;
  for (let i = 0; i < noiseData.length; i++) { seed = (seed * 1664525 + 1013904223) >>> 0; noiseData[i] = (seed / 4294967295) * 2 - 1; }
  const wind = ctx.createBufferSource(); wind.buffer = noiseBuffer; wind.loop = true; const windFilter = ctx.createBiquadFilter(); windFilter.type = 'highpass'; windFilter.frequency.value = 520;
  const windGain = ctx.createGain(); windGain.gain.value = 0; wind.connect(windFilter).connect(windGain).connect(windBus); wind.start();
  const skidGain = ctx.createGain(); skidGain.gain.value = 0; const skidFilter = ctx.createBiquadFilter(); skidFilter.type = 'bandpass'; skidFilter.frequency.value = 1050; wind.connect(skidFilter).connect(skidGain).connect(windBus);
  const combustionNoiseFilter = ctx.createBiquadFilter(); combustionNoiseFilter.type = 'bandpass'; combustionNoiseFilter.frequency.value = 460; combustionNoiseFilter.Q.value = .55; const combustionNoiseGain = ctx.createGain(); combustionNoiseGain.gain.value = .02; wind.connect(combustionNoiseFilter).connect(combustionNoiseGain).connect(exhaustBus);
  engineAudio = { ctx, master, engineBus, exhaustBus, mechanicalBus, windBus, engineResonance, exhaustFilter, pulse, body, harmonics, intake, exhaust, mechanical, limiter, gearWhine, pulseGain, bodyGain, harmonicGain, intakeGain, exhaustGain, mechanicalGain, limiterGain, gearWhineGain, windGain, skidGain, combustionNoiseGain, lastGear: 'N', lastShiftAt: -99, shiftDirection: 'up' };
  } catch (error) {
    // 某些浏览器或隐私模式禁止 Web Audio；不能让音频失败阻断比赛启动。
    console.warn('[audio] engine audio unavailable; continuing without audio', error);
    engineAudio = null;
  }
}
function updateEngineAudio() {
  if (!engineAudio) return;
  const ratio = Math.min(1, Math.abs(speed) / maxSpeed);
  const throttle = actionHeld('throttle');
  const now = engineAudio.ctx.currentTime;
  const gear = currentGear === 0 ? 'N' : String(currentGear);
  const gearTone = { N:[.82,720,1.02], 1:[1.16,1040,1.32], 2:[1.02,1260,1.15], 3:[.94,1510,1.02], 4:[.87,1810,.92], 5:[.81,2140,.84], 6:[.76,2450,.78] }[gear];
  const throttleLoad = throttle ? 1 : .52;
  const targetRpm = engineRpm;
  const pulseHz = Math.max(24, targetRpm / 60 * 2);
  const toneHz = pulseHz * gearTone[0];
  const shiftAge = now - engineAudio.lastShiftAt;
  const shiftCut = shiftAge < .05 ? 1 - .72 * (shiftAge / .05) : shiftAge < .19 ? .28 + .72 * ((shiftAge - .05) / .14) : 1;
  engineAudio.pulse.frequency.setTargetAtTime(pulseHz, now, .025);
  engineAudio.body.frequency.setTargetAtTime(toneHz, now, .03);
  engineAudio.harmonics.frequency.setTargetAtTime(toneHz * 2.01, now, .03);
  engineAudio.intake.frequency.setTargetAtTime(toneHz * 3.02, now, .035);
  engineAudio.exhaust.frequency.setTargetAtTime(toneHz * .5, now, .04);
  engineAudio.mechanical.frequency.setTargetAtTime(Math.max(35, pulseHz * 4), now, .05);
  engineAudio.gearWhine.frequency.setTargetAtTime(190 + Math.abs(speed) * 24 * gearTone[2], now, .04);
  engineAudio.pulseGain.gain.setTargetAtTime(.32 + throttleLoad * .34, now, .05);
  engineAudio.bodyGain.gain.setTargetAtTime((.38 + ratio * .32) * throttleLoad, now, .06);
  engineAudio.harmonicGain.gain.setTargetAtTime((.08 + ratio * .14) * throttleLoad, now, .06);
  engineAudio.intakeGain.gain.setTargetAtTime((throttle ? .16 : .045) + ratio * .07, now, .08);
  engineAudio.exhaustGain.gain.setTargetAtTime((throttle ? .09 : .17) + ratio * .08, now, .08);
  engineAudio.mechanicalGain.gain.setTargetAtTime(.018 + ratio * .055, now, .08);
  engineAudio.gearWhineGain.gain.setTargetAtTime(currentGear > 0 ? (.004 + ratio * .026) * (1.12 - currentGear * .055) : 0, now, .06);
  engineAudio.combustionNoiseGain.gain.setTargetAtTime((.014 + ratio * .032) * throttleLoad, now, .07);
  engineAudio.engineBus.gain.setTargetAtTime(.78 * shiftCut, now, .018);
  engineAudio.exhaustBus.gain.setTargetAtTime(.68 * (.76 + shiftCut * .24), now, .022);
  engineAudio.engineResonance.frequency.setTargetAtTime(gearTone[1] + ratio * 760, now, .1);
  engineAudio.engineResonance.gain.setTargetAtTime(3 + throttleLoad * 6, now, .12);
  engineAudio.exhaustFilter.frequency.setTargetAtTime(850 + ratio * 1700 + (throttle ? 420 : 0), now, .1);
  engineAudio.limiter.frequency.setTargetAtTime(36 + pulseHz * .33, now, .02);
  engineAudio.limiterGain.gain.setTargetAtTime(targetRpm > 7900 ? .09 : 0, now, .025);
  engineAudio.master.gain.setTargetAtTime(started && !finished ? .055 + ratio * .11 : .0001, now, .08);
  engineAudio.windGain.gain.setTargetAtTime(started && !finished ? ratio * .065 : 0, now, .12);
  engineAudio.skidGain.gain.setTargetAtTime(started && ratio > .35 ? Math.min(.06, ratio * .055) : 0, now, .08);
  if (!throttle && previousThrottle && engineRpm > 3500) playExhaustCrackle();
  previousThrottle = throttle;
}
function playShiftTone(direction = 'up') {
  if (!engineAudio) return;
  const now = engineAudio.ctx.currentTime;
  engineAudio.lastShiftAt = now; engineAudio.shiftDirection = direction;
  const osc = engineAudio.ctx.createOscillator(); const gain = engineAudio.ctx.createGain();
  osc.type = 'triangle';
  if (direction === 'up') { osc.frequency.setValueAtTime(currentGear >= 4 ? 620 : 470, now); osc.frequency.exponentialRampToValueAtTime(currentGear >= 4 ? 980 : 810, now + .065); }
  else { osc.frequency.setValueAtTime(520, now); osc.frequency.exponentialRampToValueAtTime(1080, now + .095); }
  gain.gain.setValueAtTime(.0001, now); gain.gain.exponentialRampToValueAtTime(direction === 'up' ? .09 : .065, now + .01); gain.gain.exponentialRampToValueAtTime(.0001, now + .18); osc.connect(gain).connect(engineAudio.mechanicalBus); osc.start(now); osc.stop(now + .19);
  const pop = engineAudio.ctx.createOscillator(); const popGain = engineAudio.ctx.createGain();
  pop.type = direction === 'up' ? 'square' : 'sawtooth'; pop.frequency.setValueAtTime(direction === 'up' ? 92 + currentGear * 12 : 155, now); pop.frequency.exponentialRampToValueAtTime(direction === 'up' ? 42 : 74, now + .09);
  popGain.gain.setValueAtTime(.0001, now); popGain.gain.exponentialRampToValueAtTime(direction === 'up' ? .11 : .07, now + .006); popGain.gain.exponentialRampToValueAtTime(.0001, now + .12); pop.connect(popGain).connect(engineAudio.exhaustBus); pop.start(now); pop.stop(now + .13);
}
function playExhaustCrackle() {
  if (!engineAudio) return;
  const now = engineAudio.ctx.currentTime;
  for (let i = 0; i < 2; i++) {
    const at = now + i * .055; const pop = engineAudio.ctx.createOscillator(); const gain = engineAudio.ctx.createGain();
    pop.type = 'square'; pop.frequency.setValueAtTime(78 - i * 9, at); pop.frequency.exponentialRampToValueAtTime(34, at + .055);
    gain.gain.setValueAtTime(.0001, at); gain.gain.exponentialRampToValueAtTime(.048 - i * .012, at + .004); gain.gain.exponentialRampToValueAtTime(.0001, at + .07); pop.connect(gain).connect(engineAudio.exhaustBus); pop.start(at); pop.stop(at + .075);
  }
}
function updateAutomaticTransmission(dt) {
  const kmh = Math.abs(speed) * SPEED_TO_KMH;
  if (speed < -.1 || (kmh < .5 && throttleInput < .05)) { currentGear = 0; engineRpm = THREE.MathUtils.damp(engineRpm, 1050 + (brakeInput > .1 ? 420 : 0), 8, dt); return; }
  const previousGear = currentGear;
  if (currentGear === 0) currentGear = 1;
  const wheelRpm = kmh * 37.5;
  const load = .94 + throttleInput * .12;
  const predictedRpm = wheelRpm * GEAR_RATIOS[currentGear] * load + 850;
  const rpmWantsUp = predictedRpm > 7650 && kmh > GEAR_UP_KMH[currentGear];
  const rpmWantsDown = predictedRpm < 3150 && kmh < GEAR_DOWN_KMH[currentGear];
  if (elapsed >= nextShiftAllowedAt && currentGear < 6 && rpmWantsUp && (throttleInput > .18 || kmh > GEAR_UP_KMH[currentGear] + 7)) currentGear++;
  else if (elapsed >= nextShiftAllowedAt && currentGear > 1 && rpmWantsDown) currentGear--;
  const target = THREE.MathUtils.clamp(wheelRpm * GEAR_RATIOS[currentGear] * load + 850, 1050, 8050);
  engineRpm = THREE.MathUtils.damp(engineRpm, target, throttleInput > .1 ? 12 : 7, dt);
  if (previousGear > 0 && currentGear !== previousGear) {
    const direction = currentGear > previousGear ? 'up' : 'down';
    engineRpm = direction === 'up' ? Math.max(1900, engineRpm * .76) : Math.min(8050, engineRpm + 680);
    nextShiftAllowedAt = elapsed + (direction === 'up' ? .38 : .26);
    lastShiftElapsed = elapsed;
    playShiftTone(direction);
  }
  if (engineAudio) engineAudio.lastGear = currentGear === 0 ? 'N' : String(currentGear);
}
const CAMERA_LABELS = ['远景', '近景', '车内'];
function updateCameraButton() {
  const button = $('#view-button'); if (button) button.firstChild.textContent = `${CAMERA_LABELS[cameraMode]} `;
}
function beginRace() {
  // 每场新比赛都从近景第三人称开始；比赛中仍可用 C 切换远景或车内视角。
  if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null; }
  cameraMode = 1; updateCameraButton();
  started = true; finished = false; paused = false; countdownActive = true; elapsed = 0; lap = 0; speed = 0; resetCar(); startEngineAudio(); if (engineAudio) engineAudio.lastGear = 'N';
  frontEnd.classList.add('hidden'); raceUI.classList.remove('hidden'); pauseOverlay.classList.add('hidden');
  lapEl.textContent = `0 / ${totalLaps}`; bestTimeEl.textContent = bestTimes.has(selectedTrackKey) ? formatTime(bestTimes.get(selectedTrackKey)) : '--:--.---';
  const count = $('#countdown'); let n = 3; count.textContent = n; count.classList.add('show');
  countdownTimer = setInterval(() => { n--; if (n > 0) count.textContent = n; else { countdownActive = false; count.textContent = 'GO'; setTimeout(() => count.classList.remove('show'), 420); clearInterval(countdownTimer); countdownTimer = null; } }, 650);
}
function togglePause() { if (!started || finished || countdownActive) return; paused = !paused; pauseOverlay.classList.toggle('hidden', !paused); }
function openFrontEnd(screen = 'mode') {
  frontEnd.classList.remove('hidden'); raceUI.classList.add('hidden'); pauseOverlay.classList.add('hidden');
  showScreen(screen);
}
function quitToMenu() { if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null; } countdownActive = false; $('#countdown').classList.remove('show'); started = false; paused = false; openFrontEnd('mode'); resetCar(); }
function cycleCamera() { cameraMode = (cameraMode + 1) % CAMERA_LABELS.length; updateCameraButton(); }

function update(dt) {
  if (!started || finished || paused) return;
  if (countdownActive) {
    // 倒计时只允许怠速，油门/刹车输入不会进入物理更新，GO 后下一帧才解锁。
    throttleInput = THREE.MathUtils.damp(throttleInput, 0, 18, dt);
    brakeInput = THREE.MathUtils.damp(brakeInput, 0, 18, dt);
    velocity.set(0, 0, 0); speed = 0; currentGear = 0; engineRpm = THREE.MathUtils.damp(engineRpm, 1050, 12, dt);
    return;
  }
  elapsed += dt; const throttle = actionHeld('throttle'); const reverse = actionHeld('brake');
  // 踩下 W 后更快建立油门压力，避免起步前半秒像“牛车”；松油门仍保留平滑回落。
  throttleInput = THREE.MathUtils.damp(throttleInput, throttle ? 1 : 0, throttle ? 11.5 : 9.5, dt);
  brakeInput = THREE.MathUtils.damp(brakeInput, reverse ? 1 : 0, reverse ? 12 : 9, dt);

  // 轻量级车辆动力学：纵向驱动 + 侧向抓地 + 有惯性的转向。
  // 这样高速时不会像“车屁股固定在轨道上”，低速也不会一打方向就瞬间掉头。
  const forwardBefore = new THREE.Vector3(Math.sin(heading), 0, Math.cos(heading));
  const forwardSpeed = velocity.dot(forwardBefore);
  speed = forwardSpeed;
  const speedRatio = THREE.MathUtils.clamp(Math.abs(forwardSpeed) / maxSpeed, 0, 1);

  if (reverse) {
    if (forwardSpeed > .05) {
      // S 先承担刹车，再允许倒车，避免起步误触就反向弹射。
      const brakingStep = Math.min(forwardSpeed, brakeDeceleration * brakeInput * dt);
      velocity.addScaledVector(forwardBefore, -brakingStep);
    } else {
      velocity.addScaledVector(forwardBefore, -reverseAcceleration * brakeInput * dt);
    }
  } else if (throttle && (currentGear > 0 || throttleInput > .05)) {
    const activeGear = Math.max(1, currentGear);
    const gearForce = GEAR_DRIVE_FORCE[activeGear];
    const driveFalloff = 1 - .54 * Math.pow(speedRatio, 1.45);
    const launchKmh = Math.abs(forwardSpeed) * SPEED_TO_KMH;
    // 1 挡低速额外提供约 20% 起步扭矩，并在 80 km/h 前渐退，保证直线后段仍按档位拉开。
    const lowSpeedTorque = activeGear === 1 ? THREE.MathUtils.lerp(launchTorqueBoost, 1, THREE.MathUtils.clamp(launchKmh / 80, 0, 1)) : 1;
    const shiftAge = elapsed - lastShiftElapsed;
    const clutchCoupling = shiftAge < .10 ? .22 : shiftAge < .28 ? .22 + .78 * ((shiftAge - .10) / .18) : 1;
    velocity.addScaledVector(forwardBefore, launchAcceleration * gearForce * driveFalloff * lowSpeedTorque * throttleInput * clutchCoupling * dt);
  } else {
    // 松油门时保留发动机制动，但高速不会像撞墙一样停住。
    const coastDeceleration = .34 + 1.55 * speedRatio + .72 * speedRatio * speedRatio;
    const sign = Math.sign(forwardSpeed);
    if (sign) velocity.addScaledVector(forwardBefore, -sign * coastDeceleration * dt);
  }

  // 空气阻力随速度平方增长，长直道有速度感，进弯收油也会自然减速。
  velocity.multiplyScalar(Math.max(0, 1 - (.012 + .075 * speedRatio * speedRatio) * dt));
  const steer = (actionHeld('steerLeft') ? 1 : 0) - (actionHeld('steerRight') ? 1 : 0);
  const steerResponse = assistMode === 1 ? 11 : assistMode === 2 ? 7 : 9;
  const maxSteerAngle = THREE.MathUtils.lerp(.58, .28, speedRatio);
  const steerAngle = steer * maxSteerAngle;
  const targetYawRate = THREE.MathUtils.clamp((forwardSpeed / 3.25) * Math.tan(steerAngle) * .34, -1.55, 1.55);
  yawRate = THREE.MathUtils.damp(yawRate, targetYawRate, steerResponse, dt);
  heading += yawRate * dt * (forwardSpeed >= 0 ? 1 : -1);

  const forward = new THREE.Vector3(Math.sin(heading), 0, Math.cos(heading));
  const right = new THREE.Vector3(forward.z, 0, -forward.x);
  const longitudinal = velocity.dot(forward);
  let lateral = velocity.dot(right);
  // 高速抓地更强，但仍允许一个很小的滑移窗口，让出弯不生硬。
  const grip = THREE.MathUtils.lerp(5.5, 12.5, speedRatio) * (assistMode === 1 ? 1.28 : assistMode === 2 ? .78 : 1);
  lateral *= Math.exp(-grip * dt);
  velocity.copy(forward).multiplyScalar(longitudinal).addScaledVector(right, lateral);
  speed = THREE.MathUtils.clamp(velocity.dot(forward), -reverseMaxSpeed, maxSpeed);
  velocity.copy(forward).multiplyScalar(speed).addScaledVector(right, lateral);
  car.position.addScaledVector(velocity, dt); car.rotation.y = heading;

  const info = nearestTrackInfo(car.position);
  const motionSpeed = velocity.length(); const travelDirection = motionSpeed > .8 ? velocity.clone().normalize() : forward;
  const directionDot = travelDirection.dot(info.tangent);
  if (motionSpeed * SPEED_TO_KMH > 15 && directionDot < -.35) wrongWayTime += dt;
  else wrongWayTime = Math.max(0, wrongWayTime - dt * 2.5);
  const isWrongWay = wrongWayTime > .65;
  wrongWayEl.classList.toggle('hidden', !isWrongWay);
  if (info.dist > trackWidth * .72) {
    velocity.multiplyScalar(Math.exp(-7.5 * dt)); speed = velocity.dot(forward); statusEl.textContent = '偏离赛道 · 草地抓地力降低';
  } else {
    car.position.y = THREE.MathUtils.lerp(car.position.y, info.point.y + .14, 1 - Math.pow(.002, dt)); statusEl.textContent = 'W 加速 · S 刹车/倒车 · A/D 转向 · R 回到最近赛道 · C 切换视角';
  }
  if (isWrongWay) statusEl.textContent = '方向错误 · 请掉头，或按 R 回到正确方向';
  updateAutomaticTransmission(dt);
  const progress = info.t;
  if (lastProgress > .8 && progress < .2 && speed > 2 && directionDot > .25 && elapsed > 3 && lap < totalLaps) {
    lap++;
    if (lap >= totalLaps) { finished = true; const previous = bestTimes.get(selectedTrackKey) ?? Infinity; if (elapsed < previous) bestTimes.set(selectedTrackKey, elapsed); bestTimeEl.textContent = formatTime(bestTimes.get(selectedTrackKey)); statusEl.textContent = `完成！用时 ${formatTime(elapsed)} · 按 R 重跑`; }
  }
  lastProgress = progress;
  // 物理/音频仍为 60 Hz；仪表和小地图 30 Hz 足够平滑，避免连续 textContent/布局更新造成微卡顿。
  hudAccumulator += FIXED_DT;
  if (hudAccumulator >= 1 / 30 || finished) {
    hudAccumulator = 0;
    const kmh = Math.round(Math.abs(speed) * SPEED_TO_KMH); const gear = currentGear === 0 ? 'N' : String(currentGear);
    speedEl.textContent = kmh; lapEl.textContent = Math.min(lap, totalLaps) + ' / ' + totalLaps; timeEl.textContent = formatTime(elapsed); gearEl.textContent = gear; rpmFill.style.width = Math.max(3, Math.min(100, (engineRpm - 800) / 74)) + '%'; rpmValueEl.textContent = Math.round(engineRpm).toLocaleString('en-US') + ' RPM';
    const q = minimapProject(sampleTrackPoint(progress)); mapDot.setAttribute('cx', q.x); mapDot.setAttribute('cy', q.y);
  }
}

function updateCamera(dt) {
  const forward = new THREE.Vector3(Math.sin(heading), 0, Math.cos(heading));
  if (playerCarModel) playerCarModel.visible = cameraMode !== 2;
  cockpit.visible = cameraMode === 2;
  if (cameraMode === 2) {
    // 车内驾驶视角：摄像机位于座舱中心略偏驾驶员一侧，仪表台和方向盘提供参照。
    const interiorPosition = car.position.clone().addScaledVector(forward, .08); interiorPosition.y += 1.19;
    const interiorLook = car.position.clone().addScaledVector(forward, 22); interiorLook.y += 1.14;
    camera.position.lerp(interiorPosition, 1 - Math.pow(.00001, dt)); camera.lookAt(interiorLook); return;
  }
  // 两个第三人称模式：近景仍把车完整留在画面下方，不再贴着车尾或引擎盖。
  const distance = cameraMode === 0 ? 20.5 : 11.5;
  const height = cameraMode === 0 ? 7.6 : 4.8;
  const desired = car.position.clone().addScaledVector(forward, -distance); desired.y += height;
  const look = car.position.clone().addScaledVector(forward, cameraMode === 0 ? 13.5 : 11.5); look.y += cameraMode === 0 ? 1.0 : .85;
  camera.position.lerp(desired, 1 - Math.pow(.001, dt)); camera.lookAt(look);
}
const screens = [...document.querySelectorAll('.menu-screen')];
function showScreen(name) {
  const target = screens.find((screen) => screen.dataset.screen === name) ? name : 'mode';
  screens.forEach((screen) => screen.classList.toggle('active', screen.dataset.screen === target));
  document.querySelectorAll('[data-nav]').forEach((button) => button.classList.toggle('active', button.dataset.nav === target));
}
function updateCarMenu() {
  document.querySelectorAll('[data-car]').forEach((card) => card.classList.toggle('selected', card.dataset.car === selectedCarKey));
  document.querySelectorAll('[data-car-preview]').forEach((image) => {
    const spec = CAR_OPTIONS[image.closest('[data-car]')?.dataset.car];
    if (spec) image.src = `${publicBase}assets/kenney-selected/car-kit/Previews/${spec.preview}.png`;
  });
  const readyCar = $('#ready-car'); if (readyCar) readyCar.textContent = activeCarSpec.name;
}
document.querySelectorAll('[data-next]').forEach((button) => button.addEventListener('click', () => { if (button.dataset.next === 'ready') $('#ready-laps').textContent = `${totalLaps} 圈`; showScreen(button.dataset.next); }));
document.querySelectorAll('[data-back]').forEach((button) => button.addEventListener('click', () => showScreen(button.dataset.back)));
document.querySelectorAll('[data-nav]').forEach((button) => button.addEventListener('click', () => showScreen(button.dataset.nav)));
document.querySelectorAll('[data-track]').forEach((button) => button.addEventListener('click', () => {
  document.querySelectorAll('[data-track]').forEach((card) => card.classList.toggle('selected', card === button)); buildWorld(button.dataset.track);
}));
document.querySelectorAll('[data-car]').forEach((button) => button.addEventListener('click', () => {
  selectedCarKey = button.dataset.car; applyCarSpec(selectedCarKey); updateCarMenu(); loadSelectedCar();
}));
$('#laps-option').addEventListener('click', (event) => { if (event.target.tagName === 'I') totalLaps = event.target.textContent === '+' ? (totalLaps === 3 ? 5 : 3) : (totalLaps === 5 ? 3 : 5); $('#laps-value').textContent = `${totalLaps} 圈`; });
$('#assist-option').addEventListener('click', () => { assistMode = (assistMode + 1) % 3; $('#assist-value').textContent = ['标准', '辅助', '关闭'][assistMode]; });
$('#start').addEventListener('click', beginRace); $('#pause-button').addEventListener('click', togglePause); $('#resume-button').addEventListener('click', togglePause); $('#view-button').addEventListener('click', cycleCamera); $('#menu-button').addEventListener('click', quitToMenu); $('#quit-button').addEventListener('click', quitToMenu);
updateCameraButton();
addEventListener('keydown', (event) => {
  keys.add(event.code); if (['Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(event.code)) event.preventDefault();
  // 只响应一次物理复位，避免按住 R 时浏览器重复 keydown 把车辆持续锁在原地。
  if (event.code === 'KeyR' && !event.repeat) resetCar(started); if (event.code === 'KeyC' && started) cycleCamera(); if (event.code === 'Escape' && started) togglePause(); if (event.code === 'Space' && !started && $('[data-screen="ready"]').classList.contains('active')) beginRace();
});
addEventListener('keyup', (event) => keys.delete(event.code));
addEventListener('resize', () => { camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); renderer.setSize(innerWidth, innerHeight); });

buildWorld(selectedTrackKey);
updateCircuitIcons();
applyCarSpec(selectedCarKey);
updateCarMenu();
loadSelectedCar();
openFrontEnd('mode');
window.__THREE_GAME_DIAGNOSTICS__ = () => ({
  renderer: { calls: renderer.info.render.calls, triangles: renderer.info.render.triangles, geometries: renderer.info.memory.geometries, textures: renderer.info.memory.textures, dpr: renderer.getPixelRatio() },
  state: { started, finished, paused, track: selectedTrackKey, car: selectedCarKey, lap, elapsed: Number(elapsed.toFixed(3)), speed: Number(speed.toFixed(2)), kmh: Math.round(Math.abs(speed) * SPEED_TO_KMH), gear: currentGear === 0 ? 'N' : currentGear, rpm: Math.round(engineRpm), throttle: Number(throttleInput.toFixed(2)), camera: ['far', 'near', 'cockpit'][cameraMode] },
  track: { width: trackWidth, worldScale, length: Number(trackLength.toFixed(1)), scenery: sceneryClaims.length },
});
function animate(now) {
  const frameDt = Math.min(FIXED_DT * MAX_PHYSICS_STEPS, (now - lastTime) / 1000); lastTime = now; physicsAccumulator += frameDt;
  let steps = 0; while (physicsAccumulator >= FIXED_DT && steps++ < MAX_PHYSICS_STEPS) { update(FIXED_DT); physicsAccumulator -= FIXED_DT; }
  updateEngineAudio(); updateCamera(frameDt); renderer.render(scene, camera); requestAnimationFrame(animate);
}
requestAnimationFrame(animate);
