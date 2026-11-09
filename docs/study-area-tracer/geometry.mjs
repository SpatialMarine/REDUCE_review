// Compare non-adjacent edges, including collinear contact.
export function validRing(points) {
  if (points.length < 3 || new Set(points.map(p => p.join(","))).size !== points.length) return false;
  const cross = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
  const on = (a, b, p) => p.every((v, i) => v >= Math.min(a[i], b[i]) && v <= Math.max(a[i], b[i]));
  let area = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i], b = points[(i + 1) % points.length];
    area += a[0] * b[1] - a[1] * b[0];
    for (let j = i + 2; j < points.length; j++) {
      if (i === 0 && j === points.length - 1) continue;
      const c = points[j], d = points[(j + 1) % points.length];
      const u = cross(a, b, c), v = cross(a, b, d), w = cross(c, d, a), z = cross(c, d, b);
      if ((u * v < 0 && w * z < 0) || (u === 0 && on(a, b, c)) || (v === 0 && on(a, b, d)) ||
          (w === 0 && on(c, d, a)) || (z === 0 && on(c, d, b))) return false;
    }
  }
  return Math.abs(area) > 1e-8;
}
