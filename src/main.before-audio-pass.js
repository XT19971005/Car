import * as THREE from 'three';
import { MTLLoader } from 'three/addons/loaders/MTLLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import './style.css';

const $ = (selector) => document.querySelector(selector);
const root = $('#game');
const speedEl = $('#speed');
const lapEl = $('#lap');
const timeEl = $('#time');
const bestTimeEl = $('#best-time');
const gearEl = $('#gear');
const rpmFill = $('#rpm-fill');
const mapDot = $('#map-dot');
const statusEl = $('#status');
const frontEnd = $('#front-end');
const raceUI = $('#race-ui');
const pauseOverlay = $('#pause-overlay');

// 现代 GP 布局的等比例游戏化描点。公里数使用真实数据，世界尺寸压缩到适合网页驾驶的范围。
const TRACKS = {
  monza: {
    name: '蒙扎', country: '意大利 · 蒙扎', distance: '5.793 KM', corners: '11 弯', number: '01', theme: '意大利林园',
    sky: 0xa9d5e2, fog: 0xa9d5e2, ground: 0x588a4f, curbA: 0xd22e27, curbB: 0xf2eee2,
    points: [
      [24,72,0],[-8,72,0],[-42,72,0],[-72,71,0],[-83,65,0],[-76,56,0],[-85,48,0],[-96,43,0],
      [-105,31,0],[-108,14,0],[-105,-3,0],[-96,-16,0],[-82,-23,0],[-68,-25,0],[-61,-33,0],[-52,-28,0],
      [-45,-37,0],[-43,-50,0],[-36,-61,0],[-25,-65,0],[-14,-60,0],[-7,-50,0],[-5,-38,0],
      [5,-23,0],[18,-7,0],[31,10,0],[38,21,0],[47,27,0],[43,35,0],[52,42,0],[63,40,0],
      [80,41,0],[98,44,0],[108,52,0],[111,63,0],[106,74,0],[96,81,0],[82,83,0],[67,79,0],[54,73,0],
    ],
    markers: [[.10,-1,150],[.12,-1,100],[.14,-1,50],[.70,1,100]],
  },
  spa: {
    name: '斯帕-弗朗科尔尚', country: '比利时 · 阿登', distance: '7.004 KM', corners: '19 弯', number: '02', theme: '阿登山林',
    sky: 0x98bbc5, fog: 0x98bbc5, ground: 0x3f7548, curbA: 0xd52d2b, curbB: 0xf0efe8,
    points: [
      [60,70,2],[75,70,2],[86,64,1],[90,54,0],[86,44,-1],[75,40,-1],[62,44,0],[49,45,1],
      [38,38,2],[30,30,3],[23,21,6],[27,11,10],[21,1,14],[10,-10,16],[-6,-24,17],[-25,-38,17],
      [-46,-52,16],[-65,-61,15],[-79,-59,13],[-88,-51,11],[-83,-42,10],[-70,-36,9],[-58,-27,8],
      [-54,-16,7],[-60,-6,5],[-58,5,4],[-49,14,3],[-36,18,2],[-23,17,2],[-12,10,2],
      [0,20,2],[15,35,2],[25,50,2],[40,60,2],[55,62,2],[60,60,2],[52,66,2],[52,76,2],
    ],
    markers: [[.07,-1,100],[.09,-1,50],[.48,1,100],[.83,-1,100]],
  },
  silverstone: {
    name: '银石', country: '英国 · 北安普敦郡', distance: '5.890 KM', corners: '18 弯', number: '03', theme: '英国机场',
    sky: 0xb7c8ce, fog: 0xb7c8ce, ground: 0x617856, curbA: 0x2f678d, curbB: 0xf3eee1,
    points: [
      [18,73,0],[39,72,0],[51,66,0],[54,56,0],[49,45,0],[38,37,0],[28,28,0],[29,16,0],[38,6,0],[37,-5,0],
      [28,-13,0],[17,-9,0],[8,1,0],[-1,10,0],[-10,7,0],[-14,-5,0],[-19,-20,0],[-29,-29,0],[-42,-32,0],
      [-57,-27,0],[-69,-18,0],[-74,-6,0],[-71,7,0],[-61,17,0],[-49,22,0],[-36,25,0],[-25,30,0],[-17,40,0],
      [-11,52,0],[-1,58,0],[10,57,0],[16,51,0],[22,60,0],[24,68,0],[18,73,0],
    ],
    markers: [[.12,1,100],[.34,-1,100],[.61,1,100],[.88,-1,100]],
  },
  nurburgring: {
    name: '纽博格林 GP', country: '德国 · 艾费尔', distance: '5.148 KM', corners: '15 弯', number: '04', theme: '艾费尔丘陵',
    sky: 0x9fb5b5, fog: 0x9fb5b5, ground: 0x466b45, curbA: 0xd52822, curbB: 0xf0eee5,
    points: [
      [48,62,2],[69,59,2],[82,50,1],[83,39,0],[76,32,0],[64,34,1],[55,43,2],[43,46,3],[30,42,4],[21,33,5],
      [18,22,5],[23,13,4],[34,10,3],[41,3,2],[39,-7,1],[29,-14,0],[17,-14,0],[8,-21,-1],[7,-33,-2],[14,-44,-3],
      [10,-54,-4],[-2,-59,-4],[-14,-55,-3],[-21,-44,-2],[-20,-31,-1],[-15,-19,0],[-21,-9,1],[-34,-5,2],[-47,3,4],
      [-57,15,5],[-61,29,6],[-56,39,6],[-45,40,6],[-37,33,5],[-34,23,4],[-27,17,3],[-17,19,3],[-10,28,3],
      [-9,41,3],[-2,52,3],[10,59,2],[27,62,2],
    ],
    markers: [[.08,-1,100],[.31,1,100],[.56,-1,100],[.79,1,100]],
  },
};

let selectedTrackKey = 'monza';
let selectedTrack = TRACKS[selectedTrackKey];
let totalLaps = 3;
let assistMode = 0;
let paused = false;
let cameraMode = 0;
let trackCurve;
let trackLength = 1;
let startP = new THREE.Vector3();
let startT = new THREE.Vector3(0, 0, 1);
let minimapProject = () => ({ x: 0, y: 0 });
const sampleCount = 520;
const trackWidth = 10.8;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.1, 1400);
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
root.appendChild(renderer.domElement);

scene.add(new THREE.HemisphereLight(0xe8f7ff, 0x40564a, 2.2));
const sun = new THREE.DirectionalLight(0xfff1cf, 3.5);
sun.position.set(-60, 90, 30); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -360; sun.shadow.camera.right = 360; sun.shadow.camera.top = 360; sun.shadow.camera.bottom = -360;
scene.add(sun);
const groundMaterial = new THREE.MeshStandardMaterial({ color: selectedTrack.ground, roughness: 1 });
const ground = new THREE.Mesh(new THREE.PlaneGeometry(1400, 1400), groundMaterial);
ground.rotation.x = -Math.PI / 2; ground.position.y = -0.08; ground.receiveShadow = true; scene.add(ground);
let world = new THREE.Group(); scene.add(world);
let worldGeneration = 0;
let sceneryClaims = [];

const assetBase = '/assets/kenney-selected/racing-kit/Models/OBJ%20format/';
const roadsBase = '/assets/kenney-selected/city-kit-roads/Models/OBJ%20format/';
const industrialBase = '/assets/kenney-selected/city-kit-industrial/Models/OBJ%20format/';
const suburbanBase = '/assets/kenney-selected/city-kit-suburban/Models/OBJ%20format/';
const natureBase = '/assets/kenney-selected/nature-kit/Models/OBJ%20format/';
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
  for (let i = 0; i < sampleCount; i += 2) { const p = trackCurve.getPointAt(i / sampleCount); best = Math.min(best, Math.hypot(position.x - p.x, position.z - p.z)); }
  return best;
}

function loadKitOnTrack(base, stem, size, t, sign, offset, rotationOffset = 0, advance = 0, generation = worldGeneration) {
  const radius = Math.max(2.2, size * .62); let resolvedOffset = Math.max(offset, trackWidth / 2 + radius + 5); let pose = trackPose(t, sign, resolvedOffset, advance);
  const safeDistance = trackWidth / 2 + radius + 3; let attempts = 0;
  const overlapsClaim = () => sceneryClaims.some((claim) => Math.hypot(claim.x - pose.position.x, claim.z - pose.position.z) < claim.radius + radius + 2);
  while ((horizontalDistanceToTrack(pose.position) < safeDistance || overlapsClaim()) && attempts++ < 16) { resolvedOffset += 5; pose = trackPose(t, sign, resolvedOffset, advance); }
  sceneryClaims.push({ x: pose.position.x, z: pose.position.z, radius });
  return getKitTemplate(base, stem).then((template) => {
    if (generation !== worldGeneration) return;
    const model = template.clone(true); const rawBox = new THREE.Box3().setFromObject(model); const rawSize = rawBox.getSize(new THREE.Vector3());
    model.scale.setScalar(size / Math.max(rawSize.x, rawSize.y, rawSize.z)); model.rotation.y = pose.rotation + rotationOffset; model.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(model); const center = box.getCenter(new THREE.Vector3());
    model.position.set(pose.position.x - center.x, pose.position.y - box.min.y, pose.position.z - center.z);
    model.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } }); world.add(model);
  }).catch((error) => console.warn(`[asset] ${stem}`, error));
}

function meshFromStrip(positions, indices, material, uvs = null) {
  const geometry = new THREE.BufferGeometry(); geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3)); geometry.setIndex(indices); geometry.computeVertexNormals();
  if (uvs) geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  const mesh = new THREE.Mesh(geometry, material); mesh.receiveShadow = true; world.add(mesh); return mesh;
}

function addPaddockSlab(t, sign, offset, width, length) {
  const radius = Math.hypot(width, length) * .52; let resolvedOffset = Math.max(offset, trackWidth / 2 + radius + 5); let pose = trackPose(t, sign, resolvedOffset);
  let attempts = 0; const overlapsClaim = () => sceneryClaims.some((claim) => Math.hypot(claim.x - pose.position.x, claim.z - pose.position.z) < claim.radius + radius + 2);
  while ((horizontalDistanceToTrack(pose.position) < trackWidth / 2 + radius + 3 || overlapsClaim()) && attempts++ < 16) { resolvedOffset += 5; pose = trackPose(t, sign, resolvedOffset); }
  sceneryClaims.push({ x: pose.position.x, z: pose.position.z, radius });
  const slab = new THREE.Mesh(new THREE.BoxGeometry(width, .12, length), new THREE.MeshStandardMaterial({ color: 0x747a78, roughness: .96 }));
  slab.position.copy(pose.position); slab.position.y += .02; slab.rotation.y = pose.rotation; slab.receiveShadow = true; world.add(slab);
}

function addBrakeMarker(t, sign, number) {
  const pose = trackPose(t, sign, trackWidth / 2 + 3.3); const group = new THREE.Group();
  const post = new THREE.Mesh(new THREE.BoxGeometry(.11, 2.15, .11), new THREE.MeshStandardMaterial({ color: 0xd3d5d6 })); post.position.y = 1.07;
  const label = document.createElement('canvas'); label.width = 128; label.height = 80; const ctx = label.getContext('2d');
  ctx.fillStyle = '#f5f1e7'; ctx.fillRect(0, 0, 128, 80); ctx.fillStyle = '#171a1d'; ctx.font = 'bold 45px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(String(number), 64, 42);
  const board = new THREE.Mesh(new THREE.BoxGeometry(1.05, .68, .08), new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(label) })); board.position.y = 1.78;
  group.add(post, board); group.position.copy(pose.position); group.rotation.y = pose.rotation; world.add(group);
}

function buildMinimap() {
  const samples = Array.from({ length: 180 }, (_, i) => trackCurve.getPointAt(i / 180));
  const minX = Math.min(...samples.map((p) => p.x)); const maxX = Math.max(...samples.map((p) => p.x)); const minZ = Math.min(...samples.map((p) => p.z)); const maxZ = Math.max(...samples.map((p) => p.z));
  const scale = Math.min(184 / (maxX - minX), 105 / (maxZ - minZ));
  minimapProject = (p) => ({ x: 110 + (p.x - (minX + maxX) / 2) * scale, y: 67.5 + (p.z - (minZ + maxZ) / 2) * scale });
  const d = samples.map((p, i) => { const q = minimapProject(p); return `${i ? 'L' : 'M'}${q.x.toFixed(1)} ${q.y.toFixed(1)}`; }).join(' ') + ' Z';
  $('.map-shadow').setAttribute('d', d); $('.map-line').setAttribute('d', d); const first = minimapProject(samples[0]); mapDot.setAttribute('cx', first.x); mapDot.setAttribute('cy', first.y);
  $('#hud-track-number').textContent = selectedTrack.number; $('#hud-track-name').textContent = selectedTrack.name; $('#hud-track-distance').textContent = selectedTrack.distance; $('#ready-track').textContent = selectedTrack.name;
}

function buildWorld(key) {
  selectedTrackKey = key; selectedTrack = TRACKS[key]; worldGeneration++;
  scene.remove(world); world = new THREE.Group(); scene.add(world); sceneryClaims = [];
  scene.background = new THREE.Color(selectedTrack.sky); scene.fog = new THREE.Fog(selectedTrack.fog, 180, 680); groundMaterial.color.setHex(selectedTrack.ground);
  const minElevation = Math.min(...selectedTrack.points.map((point) => point[2]));
  const vectors = selectedTrack.points.map(([x, z, y]) => new THREE.Vector3(x * 2.45, (y - minElevation) * .38, z * 2.45));
  trackCurve = new THREE.CatmullRomCurve3(vectors, true, 'centripetal'); trackCurve.arcLengthDivisions = 1200; trackLength = trackCurve.getLength();
  startP = trackCurve.getPointAt(0); startT = trackCurve.getTangentAt(0).normalize();

  const roadPositions = []; const roadUvs = []; const shoulderPositions = []; const indices = [];
  for (let i = 0; i <= sampleCount; i++) {
    const t = i / sampleCount; const p = trackCurve.getPointAt(t); const tangent = trackCurve.getTangentAt(t).normalize(); const side = new THREE.Vector3(-tangent.z, 0, tangent.x).normalize();
    const left = p.clone().addScaledVector(side, trackWidth / 2); const right = p.clone().addScaledVector(side, -trackWidth / 2);
    const shoulderLeft = p.clone().addScaledVector(side, trackWidth / 2 + .85); const shoulderRight = p.clone().addScaledVector(side, -trackWidth / 2 - .85);
    roadPositions.push(left.x, left.y + .07, left.z, right.x, right.y + .07, right.z);
    shoulderPositions.push(shoulderLeft.x, shoulderLeft.y + .015, shoulderLeft.z, shoulderRight.x, shoulderRight.y + .015, shoulderRight.z);
    const repeat = t * Math.max(18, trackLength / 18); roadUvs.push(0, repeat, 1, repeat);
    if (i < sampleCount) { const n = i + 1; indices.push(i * 2, i * 2 + 1, n * 2, i * 2 + 1, n * 2 + 1, n * 2); }
  }
  meshFromStrip(shoulderPositions, indices, new THREE.MeshStandardMaterial({ color: 0xc9c3aa, roughness: 1, side: THREE.DoubleSide }));
  const roadTexture = new THREE.TextureLoader().load('/assets/kenney-selected/road-textures/PNG/Default/roadTexture_01.png');
  roadTexture.wrapS = roadTexture.wrapT = THREE.RepeatWrapping; roadTexture.colorSpace = THREE.SRGBColorSpace; roadTexture.anisotropy = renderer.capabilities.getMaxAnisotropy();
  meshFromStrip(roadPositions, indices, new THREE.MeshStandardMaterial({ color: 0xdfe3e2, map: roadTexture, roughness: .94, side: THREE.DoubleSide }), roadUvs);

  const startLine = new THREE.Mesh(new THREE.BoxGeometry(trackWidth, .035, .85), new THREE.MeshStandardMaterial({ color: 0xf7f0d0 }));
  startLine.position.copy(startP); startLine.position.y += .115; startLine.rotation.y = Math.atan2(startT.x, startT.z); world.add(startLine);
  const lineMat = new THREE.MeshBasicMaterial({ color: 0xf6f1df });
  const curbMats = [new THREE.MeshStandardMaterial({ color: selectedTrack.curbA }), new THREE.MeshStandardMaterial({ color: selectedTrack.curbB })];
  for (let i = 1; i < sampleCount; i += 6) {
    const t = i / sampleCount; const p = trackCurve.getPointAt(t); const tan = trackCurve.getTangentAt(t).normalize(); const rot = Math.atan2(tan.x, tan.z); const side = new THREE.Vector3(-tan.z, 0, tan.x).normalize();
    const dash = new THREE.Mesh(new THREE.BoxGeometry(.12, .025, 2), lineMat); dash.position.copy(p); dash.position.y += .115; dash.rotation.y = rot; world.add(dash);
    for (const sign of [-1, 1]) {
      const curb = new THREE.Mesh(new THREE.BoxGeometry(.52, .065, .9), curbMats[(i / 6) % 2 | 0]);
      curb.position.copy(p).addScaledVector(side, sign * (trackWidth / 2 + .38)); curb.position.y += .105; curb.rotation.y = rot; world.add(curb);
    }
  }
  selectedTrack.markers.forEach((entry) => addBrakeMarker(...entry));

  // 所有实体设施只生成在路肩安全区以外，柏油路面保持完全净空。
  addPaddockSlab(.015, 1, 38, 24, 48); addPaddockSlab(.04, -1, 40, 26, 50);
  const generation = worldGeneration;
  loadKitOnTrack(assetBase, 'grandStandCovered', 20, .025, 1, 40, 0, 3, generation);
  loadKitOnTrack(assetBase, 'pitsGarage', 20, .035, -1, 42, 0, 2, generation);
  loadKitOnTrack(assetBase, 'pitsOffice', 14, .12, -1, 38, 0, 0, generation);
  loadKitOnTrack(assetBase, 'bannerTowerRed', 8, .10, 1, 24, 0, 0, generation);
  loadKitOnTrack(assetBase, 'bannerTowerGreen', 8, .16, -1, 24, 0, 0, generation);
  for (const [t, sign] of [[.18,1],[.34,-1],[.51,1],[.69,-1],[.84,1]]) loadKitOnTrack(assetBase, 'billboardLow', 5.5, t, sign, 15, Math.PI / 2, 0, generation);
  for (const [t, sign] of [[.08,1],[.23,-1],[.42,1],[.62,-1],[.78,1],[.93,-1]]) loadKitOnTrack(assetBase, 'lightPostModern', 7.5, t, sign, 13, 0, 0, generation);

  const themeLandmarks = {
    monza: [[suburbanBase,'building-type-c',13,.42,1,31],[industrialBase,'water-tower',14,.68,-1,34]],
    spa: [[suburbanBase,'building-type-g',13,.16,-1,30],[roadsBase,'bridge-pillar-wide',9,.56,1,22]],
    silverstone: [[industrialBase,'building-a',19,.31,-1,33],[industrialBase,'building-f',17,.35,-1,34]],
    nurburgring: [[suburbanBase,'building-type-a',13,.24,1,31],[industrialBase,'water-tower',14,.76,-1,34]],
  }[key];
  themeLandmarks.forEach(([base, stem, size, t, sign, offset]) => loadKitOnTrack(base, stem, size, t, sign, offset, 0, 0, generation));
  const natureStems = ['tree_pineTallA_detailed','tree_pineTallB_detailed','tree_pineRoundA','tree_oak','tree_detailed'];
  for (let i = 0; i < 30; i++) {
    const t = (i * .037 + .11) % 1; const sign = i % 2 ? 1 : -1; const offset = 23 + (i % 4) * 6;
    loadKitOnTrack(natureBase, natureStems[i % natureStems.length], 8 + (i % 3), t, sign, offset, i * .47, (i % 3) * 3, generation);
  }
  const mountainColors = key === 'silverstone' ? [0x75847f,0x687873] : [0x557276,0x3f5c60,0x31484d];
  for (let i = 0; i < (key === 'silverstone' ? 5 : 14); i++) {
    const mountain = new THREE.Mesh(new THREE.ConeGeometry(20 + (i % 3) * 8, 24 + (i % 4) * 8, 5), new THREE.MeshBasicMaterial({ color: mountainColors[i % mountainColors.length] }));
    const angle = (i / 14) * Math.PI * 2; const radius = 480 + (i % 2) * 55; mountain.position.set(Math.cos(angle) * radius, 8, Math.sin(angle) * radius); mountain.rotation.y = i * .73; world.add(mountain);
  }
  buildMinimap(); if (car) resetCar();
  console.info(`[track] ${selectedTrack.name}`, { length: trackLength.toFixed(1), clearance: 'asphalt clear' });
}

let car = new THREE.Group(); scene.add(car);
const headLampMat = new THREE.MeshBasicMaterial({ color: 0xfff5d0 }); const tailLampMat = new THREE.MeshBasicMaterial({ color: 0xf22a1d });
for (const x of [-.78, .78]) {
  const head = new THREE.Mesh(new THREE.BoxGeometry(.22, .1, .06), headLampMat); head.position.set(x, .7, 2.08); car.add(head);
  const tail = new THREE.Mesh(new THREE.BoxGeometry(.24, .11, .06), tailLampMat); tail.position.set(x, .7, -2.08); car.add(tail);
}
const headGlow = new THREE.PointLight(0xffe5bd, 1.15, 10); headGlow.position.set(0, .62, 2.25); car.add(headGlow);
function fitPlayerCar(model, targetLength = 4.35) {
  const rawBox = new THREE.Box3().setFromObject(model); const rawSize = rawBox.getSize(new THREE.Vector3()); model.scale.setScalar(targetLength / rawSize.z); model.updateMatrixWorld(true);
  const scaledBox = new THREE.Box3().setFromObject(model); model.position.y = -scaledBox.min.y; model.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } }); car.add(model);
}
function addFallbackRacingCar() {
  const mtl = new MTLLoader(); mtl.setPath(assetBase); mtl.load('raceCarRed.mtl', (materials) => { materials.preload(); const loader = new OBJLoader(); loader.setMaterials(materials); loader.setPath(assetBase); loader.load('raceCarRed.obj', fitPlayerCar); });
}
const carLoader = new GLTFLoader(); carLoader.setPath('/assets/kenney-selected/car-kit/Models/GLB%20format/'); carLoader.load('sedan-sports.glb', (gltf) => fitPlayerCar(gltf.scene), undefined, addFallbackRacingCar);

let started = false; let finished = false; let elapsed = 0; let lap = 0; let speed = 0; let heading = 0; let lastProgress = 0; let lastTime = performance.now();
const bestTimes = new Map(); const maxSpeed = 34; const accel = 19; const brake = 29; const keys = new Set();
function nearestTrackInfo(pos) {
  let best = { dist: Infinity, t: 0, point: startP };
  for (let i = 0; i < sampleCount; i += 2) { const t = i / sampleCount; const p = trackCurve.getPointAt(t); const d = Math.hypot(p.x - pos.x, p.z - pos.z); if (d < best.dist) best = { dist: d, t, point: p }; }
  return best;
}
function formatTime(v) { const m = Math.floor(v / 60); const s = (v % 60).toFixed(3).padStart(6, '0'); return `${String(m).padStart(2, '0')}:${s}`; }
function resetCar() { car.position.copy(startP); car.position.y += .14; heading = Math.atan2(startT.x, startT.z); car.rotation.y = heading; speed = 0; lastProgress = 0; }

let engineAudio;
function startEngineAudio() {
  if (engineAudio) { engineAudio.ctx.resume(); return; }
  const ctx = new AudioContext(); const master = ctx.createGain(); master.gain.value = .0001; master.connect(ctx.destination);
  const filter = ctx.createBiquadFilter(); filter.type = 'lowpass'; filter.frequency.value = 900; filter.Q.value = .8; filter.connect(master);
  const body = ctx.createOscillator(); body.type = 'sawtooth'; const bodyGain = ctx.createGain(); bodyGain.gain.value = .72; body.connect(bodyGain).connect(filter); body.start();
  const harmonics = ctx.createOscillator(); harmonics.type = 'square'; const harmonicGain = ctx.createGain(); harmonicGain.gain.value = .16; harmonics.connect(harmonicGain).connect(filter); harmonics.start();
  const rumble = ctx.createOscillator(); rumble.type = 'triangle'; const rumbleGain = ctx.createGain(); rumbleGain.gain.value = .23; rumble.connect(rumbleGain).connect(filter); rumble.start();
  const noiseBuffer = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate); const noiseData = noiseBuffer.getChannelData(0); let seed = 1337;
  for (let i = 0; i < noiseData.length; i++) { seed = (seed * 1664525 + 1013904223) >>> 0; noiseData[i] = (seed / 4294967295) * 2 - 1; }
  const wind = ctx.createBufferSource(); wind.buffer = noiseBuffer; wind.loop = true; const windFilter = ctx.createBiquadFilter(); windFilter.type = 'highpass'; windFilter.frequency.value = 480;
  const windGain = ctx.createGain(); windGain.gain.value = 0; wind.connect(windFilter).connect(windGain).connect(master); wind.start();
  const skidGain = ctx.createGain(); skidGain.gain.value = 0; const skidFilter = ctx.createBiquadFilter(); skidFilter.type = 'bandpass'; skidFilter.frequency.value = 900; wind.connect(skidFilter).connect(skidGain).connect(master);
  engineAudio = { ctx, master, filter, body, harmonics, rumble, bodyGain, harmonicGain, rumbleGain, windGain, skidGain, lastGear: 'N' };
}
function updateEngineAudio() {
  if (!engineAudio) return;
  const ratio = Math.min(1, Math.abs(speed) / maxSpeed); const throttle = keys.has('KeyW') || keys.has('ArrowUp'); const now = engineAudio.ctx.currentTime; const kmh = Math.abs(speed) * 7.2;
  const gear = kmh < 3 ? 'N' : String(Math.min(6, Math.max(1, Math.floor(kmh / 36) + 1)));
  const profile = { N:[.72,620,.48,.08], 1:[.84,740,.78,.11], 2:[.96,980,.72,.16], 3:[1.08,1220,.67,.2], 4:[1.2,1560,.56,.24], 5:[1.3,1900,.5,.28], 6:[1.42,2300,.44,.34] }[gear];
  const rpm = (50 + ratio * 215 + (throttle ? 14 : 0)) * profile[0];
  engineAudio.bodyGain.gain.setTargetAtTime(profile[2], now, .06); engineAudio.harmonicGain.gain.setTargetAtTime(profile[3], now, .06);
  engineAudio.body.frequency.setTargetAtTime(rpm, now, .035); engineAudio.harmonics.frequency.setTargetAtTime(rpm * 2.01, now, .035); engineAudio.rumble.frequency.setTargetAtTime(rpm * .49, now, .05);
  engineAudio.filter.frequency.setTargetAtTime(profile[1] + ratio * 900, now, .08); engineAudio.master.gain.setTargetAtTime(started && !finished ? .045 + ratio * .09 : .0001, now, .08);
  engineAudio.windGain.gain.setTargetAtTime(started && !finished ? ratio * .055 : 0, now, .12); engineAudio.skidGain.gain.setTargetAtTime(started && ratio > .35 ? Math.min(.055, ratio * .05) : 0, now, .08);
}
function playShiftTone() {
  if (!engineAudio) return; const now = engineAudio.ctx.currentTime; const osc = engineAudio.ctx.createOscillator(); const gain = engineAudio.ctx.createGain();
  osc.type = 'triangle'; osc.frequency.setValueAtTime(480, now); osc.frequency.exponentialRampToValueAtTime(710, now + .07); gain.gain.setValueAtTime(.0001, now); gain.gain.exponentialRampToValueAtTime(.065, now + .01); gain.gain.exponentialRampToValueAtTime(.0001, now + .14); osc.connect(gain).connect(engineAudio.master); osc.start(now); osc.stop(now + .16);
}

function beginRace() {
  started = true; finished = false; paused = false; elapsed = 0; lap = 0; speed = 0; resetCar(); startEngineAudio(); if (engineAudio) engineAudio.lastGear = 'N';
  frontEnd.classList.add('hidden'); raceUI.classList.remove('hidden'); pauseOverlay.classList.add('hidden');
  lapEl.textContent = `0 / ${totalLaps}`; bestTimeEl.textContent = bestTimes.has(selectedTrackKey) ? formatTime(bestTimes.get(selectedTrackKey)) : '--:--.---';
  const count = $('#countdown'); let n = 3; count.textContent = n; count.classList.add('show');
  const timer = setInterval(() => { n--; if (n > 0) count.textContent = n; else { count.textContent = 'GO'; setTimeout(() => count.classList.remove('show'), 420); clearInterval(timer); } }, 650);
}
function togglePause() { if (!started || finished) return; paused = !paused; pauseOverlay.classList.toggle('hidden', !paused); }
function quitToMenu() { started = false; paused = false; pauseOverlay.classList.add('hidden'); raceUI.classList.add('hidden'); frontEnd.classList.remove('hidden'); showScreen('mode'); resetCar(); }
function cycleCamera() { cameraMode = (cameraMode + 1) % 3; $('#view-button').firstChild.textContent = ['远景 ', '近景 ', '引擎盖 '][cameraMode]; }

function update(dt) {
  if (!started || finished || paused) return;
  elapsed += dt; const throttle = keys.has('KeyW') || keys.has('ArrowUp'); const reverse = keys.has('KeyS') || keys.has('ArrowDown');
  if (throttle) speed = Math.min(maxSpeed, speed + accel * dt); else if (reverse) speed = Math.max(-maxSpeed * .35, speed - brake * dt); else speed *= Math.pow(.18, dt);
  const steer = (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0) - (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0);
  heading += steer * 1.9 * Math.min(1, Math.abs(speed) / 7) * (assistMode === 1 ? .78 : 1) * dt * (speed >= 0 ? 1 : -1);
  car.position.x += Math.sin(heading) * speed * dt; car.position.z += Math.cos(heading) * speed * dt; car.rotation.y = heading;
  const info = nearestTrackInfo(car.position);
  if (info.dist > trackWidth * .72) { speed *= Math.pow(.035, dt); statusEl.textContent = '偏离赛道 · 回到柏油路面'; }
  else { car.position.y = THREE.MathUtils.lerp(car.position.y, info.point.y + .14, 1 - Math.pow(.002, dt)); statusEl.textContent = 'W 加速 · S 刹车/倒车 · A/D 转向'; }
  const progress = info.t;
  if (lastProgress > .8 && progress < .2 && speed > 2 && elapsed > 3 && lap < totalLaps) {
    lap++;
    if (lap >= totalLaps) { finished = true; const previous = bestTimes.get(selectedTrackKey) ?? Infinity; if (elapsed < previous) bestTimes.set(selectedTrackKey, elapsed); bestTimeEl.textContent = formatTime(bestTimes.get(selectedTrackKey)); statusEl.textContent = `完成！用时 ${formatTime(elapsed)} · 按 R 重跑`; }
  }
  lastProgress = progress;
  const kmh = Math.round(Math.abs(speed) * 7.2); const gear = kmh < 3 ? 'N' : String(Math.min(6, Math.max(1, Math.floor(kmh / 36) + 1)));
  speedEl.textContent = kmh; lapEl.textContent = `${Math.min(lap, totalLaps)} / ${totalLaps}`; timeEl.textContent = formatTime(elapsed); gearEl.textContent = gear; rpmFill.style.width = `${Math.max(3, Math.min(100, kmh / 2.35))}%`;
  if (gear !== engineAudio?.lastGear && gear !== 'N') { playShiftTone(); engineAudio.lastGear = gear; }
  const q = minimapProject(trackCurve.getPointAt(progress)); mapDot.setAttribute('cx', q.x); mapDot.setAttribute('cy', q.y);
}

function updateCamera(dt) {
  const forward = new THREE.Vector3(Math.sin(heading), 0, Math.cos(heading)); let desired; let look;
  if (cameraMode === 2) {
    // 真正的车头视角：位于引擎盖前部并看向前方道路，不显示车屁股。
    desired = car.position.clone().addScaledVector(forward, 1.7); desired.y += 1.55; look = desired.clone().addScaledVector(forward, 18); look.y += .08;
  } else {
    const distance = cameraMode === 0 ? 13.5 : 7.5; const height = cameraMode === 0 ? 5.2 : 3.05;
    desired = car.position.clone().addScaledVector(forward, -distance); desired.y += height; look = car.position.clone().addScaledVector(forward, cameraMode === 0 ? 8 : 7); look.y += 1;
  }
  camera.position.lerp(desired, 1 - Math.pow(cameraMode === 2 ? .00002 : .001, dt)); camera.lookAt(look);
  camera.fov = THREE.MathUtils.lerp(camera.fov, (cameraMode === 2 ? 68 : 58) + Math.min(1, Math.abs(speed) / maxSpeed) * 7, 1 - Math.pow(.02, dt)); camera.updateProjectionMatrix();
}

const screens = [...document.querySelectorAll('.menu-screen')];
function showScreen(name) { screens.forEach((screen) => screen.classList.toggle('active', screen.dataset.screen === name)); }
document.querySelectorAll('[data-next]').forEach((button) => button.addEventListener('click', () => { if (button.dataset.next === 'ready') $('#ready-laps').textContent = `${totalLaps} 圈`; showScreen(button.dataset.next); }));
document.querySelectorAll('[data-back]').forEach((button) => button.addEventListener('click', () => showScreen(button.dataset.back)));
document.querySelectorAll('[data-track]').forEach((button) => button.addEventListener('click', () => {
  document.querySelectorAll('[data-track]').forEach((card) => card.classList.toggle('selected', card === button)); buildWorld(button.dataset.track);
}));
$('#laps-option').addEventListener('click', (event) => { if (event.target.tagName === 'I') totalLaps = event.target.textContent === '+' ? (totalLaps === 3 ? 5 : 3) : (totalLaps === 5 ? 3 : 5); $('#laps-value').textContent = `${totalLaps} 圈`; });
$('#assist-option').addEventListener('click', () => { assistMode = (assistMode + 1) % 3; $('#assist-value').textContent = ['标准', '辅助', '关闭'][assistMode]; });
$('#start').addEventListener('click', beginRace); $('#pause-button').addEventListener('click', togglePause); $('#resume-button').addEventListener('click', togglePause); $('#view-button').addEventListener('click', cycleCamera); $('#menu-button').addEventListener('click', quitToMenu); $('#quit-button').addEventListener('click', quitToMenu);
addEventListener('keydown', (event) => {
  keys.add(event.code); if (['Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(event.code)) event.preventDefault();
  if (event.code === 'KeyR') resetCar(); if (event.code === 'KeyC' && started) cycleCamera(); if (event.code === 'Escape' && started) togglePause(); if (event.code === 'Space' && !started && $('[data-screen="ready"]').classList.contains('active')) beginRace();
});
addEventListener('keyup', (event) => keys.delete(event.code));
addEventListener('resize', () => { camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); renderer.setSize(innerWidth, innerHeight); });

buildWorld(selectedTrackKey);
function animate(now) { const dt = Math.min(.05, (now - lastTime) / 1000); lastTime = now; update(dt); updateEngineAudio(); updateCamera(dt); renderer.render(scene, camera); requestAnimationFrame(animate); }
requestAnimationFrame(animate);
