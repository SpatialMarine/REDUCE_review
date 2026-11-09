import { validRing } from "./geometry.mjs";

const cross = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
const pair = value => Array.isArray(value) && value.length === 2 && value.every(Number.isFinite);
const geographic = value => pair(value) && Math.abs(value[0]) <= 180 && Math.abs(value[1]) <= 90;

export function readControls(data, dpi) {
  if (!Number.isFinite(data?.render_dpi) || data.render_dpi <= 0 || !Array.isArray(data.controls)) {
    throw Error("Expected calibration controls with a positive render resolution.");
  }
  return data.controls.map(({pixel, lonlat, role, note}) => {
    const draft = Array.isArray(lonlat) && lonlat.length === 2 &&
      lonlat.every(v => v === null || Number.isFinite(v));
    if (!pair(pixel) || !draft || !["fit", "check"].includes(role)) {
      throw Error("A control point has invalid pixels, coordinates or role.");
    }
    return {pixel: pixel.map(v => v * dpi / data.render_dpi), lonlat, role, note: String(note ?? "")};
  });
}

// Centered least squares for the first-order affine model used by GIS georeferencers.
export function fitAffine(controls) {
  const fit = controls.filter(p => p.role === "fit");
  if (fit.length < 3) throw Error("Mark at least three fit points.");
  if (!controls.every(p => pair(p.pixel) && geographic(p.lonlat))) throw Error("Complete all control coordinates.");
  if (new Set(fit.map(p => p.pixel.join(","))).size !== fit.length) throw Error("Fit points must use distinct image locations.");
  const mean = (field, axis) => fit.reduce((sum, p) => sum + p[field][axis], 0) / fit.length;
  const x = mean("pixel", 0), y = mean("pixel", 1);
  const offsets = fit.map(p => [p.pixel[0] - x, p.pixel[1] - y]);
  const dot = (a, b) => a.reduce((sum, v, i) => sum + v * b[i], 0);
  const dx = offsets.map(p => p[0]), dy = offsets.map(p => p[1]);
  const xx = dot(dx, dx), yy = dot(dy, dy), xy = dot(dx, dy);
  const determinant = xx * yy - xy * xy;
  if (determinant <= 1e-10 * (xx + yy) ** 2) throw Error("Spread the fit points across the panel. They are nearly collinear.");
  if (Math.max(...fit.map(p => p.lonlat[0])) - Math.min(...fit.map(p => p.lonlat[0])) >= 180) {
    throw Error("Use QGIS for panels crossing the antimeridian or spanning 180° of longitude.");
  }
  const coefficients = [0, 1].map(axis => {
    const center = mean("lonlat", axis);
    const dz = fit.map(p => p.lonlat[axis] - center);
    const xz = dot(dx, dz), yz = dot(dy, dz);
    return [(xz * yy - yz * xy) / determinant, (yz * xx - xz * xy) / determinant, center];
  });
  const [[a, b], [c, d]] = coefficients;
  if (Math.abs(a * d - b * c) <= 1e-10 * Math.hypot(a, b) * Math.hypot(c, d)) {
    throw Error("The geographic controls collapse the panel. Check their coordinates.");
  }
  return ([px, py]) => coefficients.map(([m, n, center]) => center + m * (px - x) + n * (py - y));
}

export function fitHull(controls) {
  const pixels = controls.filter(p => p.role === "fit").map(p => p.pixel);
  pixels.sort(([ax, ay], [bx, by]) => ax - bx || ay - by);
  function half(ordered) {
    const hull = [];
    for (const p of ordered) {
      while (hull.length >= 2 && cross(hull.at(-2), hull.at(-1), p) <= 0) hull.pop();
      hull.push(p);
    }
    return hull.slice(0, -1);
  }
  return [...half(pixels), ...half(pixels.reverse())];
}

export function geographicRing(vertices, project) {
  const ring = vertices.map(project);
  if (!ring.every(geographic) || !validRing(ring)) throw Error("The fitted outline is invalid or outside WGS 84 bounds.");
  const area = ring.reduce((sum, p, i) => sum + cross(ring[0], p, ring[(i + 1) % ring.length]), 0);
  if (area < 0) ring.reverse();
  return [...ring, ring[0]];
}

export function diagnostics(controls, vertices, project) {
  const hull = fitHull(controls);
  return {
    errors: controls.map(({pixel, lonlat}) => {
      const [lon, lat] = project(pixel);
      const rad = Math.PI / 180;
      const h = Math.sin((lat - lonlat[1]) * rad / 2) ** 2 +
        Math.cos(lat * rad) * Math.cos(lonlat[1] * rad) * Math.sin((lon - lonlat[0]) * rad / 2) ** 2;
      return 12742 * Math.asin(Math.sqrt(Math.max(0, Math.min(1, h))));
    }),
    outside: vertices.filter(p => hull.some((a, i) => cross(a, hull[(i + 1) % hull.length], p) < -1e-7)).length
  };
}
