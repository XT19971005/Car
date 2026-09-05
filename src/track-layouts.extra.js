// Hand-authored low-poly centerlines for circuits not present in the F1 GeoJSON source.
// Waypoints preserve the recognisable sequence of straights, braking zones and named corners.

function makeLayout(waypoints, elevation) {
  const minX = Math.min(...waypoints.map(([x]) => x));
  const maxX = Math.max(...waypoints.map(([x]) => x));
  const minZ = Math.min(...waypoints.map(([, z]) => z));
  const maxZ = Math.max(...waypoints.map(([, z]) => z));
  const scale = 430 / Math.max(maxX - minX, maxZ - minZ);
  const centered = waypoints.map(([x, z]) => [(x - (minX + maxX) * .5) * scale, (z - (minZ + maxZ) * .5) * scale]);
  const closed = [...centered, centered[0]];
  const lengths = [0];
  for (let i = 1; i < closed.length; i++) lengths.push(lengths[i - 1] + Math.hypot(closed[i][0] - closed[i - 1][0], closed[i][1] - closed[i - 1][1]));
  const total = lengths.at(-1);
  const sampleCount = 112;
  return Array.from({ length: sampleCount }, (_, index) => {
    const distance = total * index / sampleCount;
    let segment = 1;
    while (segment < lengths.length - 1 && lengths[segment] < distance) segment++;
    const a = closed[segment - 1]; const b = closed[segment];
    const alpha = (distance - lengths[segment - 1]) / Math.max(.0001, lengths[segment] - lengths[segment - 1]);
    const t = index / sampleCount;
    return [Number((a[0] + (b[0] - a[0]) * alpha).toFixed(3)), Number((a[1] + (b[1] - a[1]) * alpha).toFixed(3)), Number(elevation(t).toFixed(3))];
  });
}

// Bathurst runs from the pit straight through Hell Corner and the Mountain,
// over the narrow Skyline/Dipper section, then down Conrod Straight and back.
const bathurstWaypoints = [
  [-140, -180], [140, -180], [180, -150], [160, -110], [130, -90],
  [120, -40], [160, 10], [120, 60], [60, 100], [0, 110], [-50, 90],
  [-90, 60], [-110, 20], [-80, -10], [-20, -35], [40, -20], [80, -40],
  [90, -90], [70, -120], [40, -150], [0, -165], [-45, -155], [-90, -150],
  [-140, -155],
];

// Laguna Seca: long start straight, Andretti hairpin, flowing Esses, the
// uphill Corkscrew and the final downhill complex returning to Turn 11.
const lagunaWaypoints = [
  [-184, -126], [-126, -126], [-63, -126], [2, -126], [65, -126], [116, -123],
  [143, -108], [149, -83], [136, -61], [106, -51], [74, -55], [50, -39],
  [38, -12], [60, 10], [91, 17], [118, 34], [112, 58], [88, 73],
  [54, 79], [21, 75], [-5, 61], [-23, 43], [-39, 42], [-52, 57],
  [-70, 73], [-97, 70], [-119, 54], [-127, 31], [-113, 9], [-88, -3],
  [-55, -5], [-26, -17], [2, -40], [39, -57], [80, -66], [116, -80],
  [135, -99], [112, -115], [67, -154], [6, -170], [-57, -160], [-124, -150], [-184, -145],
];

export const EXTRA_TRACK_LAYOUTS = {
  bathurst: makeLayout(bathurstWaypoints, (t) => 10 + Math.sin(t * Math.PI * 2 - .4) * 14 + Math.sin(t * Math.PI * 6) * 3),
  laguna: makeLayout(lagunaWaypoints, (t) => 7 + Math.sin(t * Math.PI * 2 + .9) * 5 + Math.sin(t * Math.PI * 8) * 2),
};
