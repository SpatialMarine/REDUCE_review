import { fitAffine, fitHull, geographicRing, diagnostics, readControls } from "./georeference.mjs";

const $ = id => document.getElementById(id);
const svg = $("geo-preview");
const reviewItems = {
  markers_verified: $("review-markers"),
  checks_verified: $("review-checks"),
  errors_acceptable: $("review-errors"),
  extent_reviewed: $("review-extent")
};

export function createCalibration({dpi, context, repaint, download}) {
  let controls = [], baseline = [], moving = null, result;

  function input(type, value, label, onChange) {
    const field = document.createElement("input");
    field.type = type;
    field.value = value ?? "";
    field.setAttribute("aria-label", label);
    if (type === "number") field.step = "any";
    field.oninput = () => {
      onChange(type === "number" ? (field.value === "" ? null : field.valueAsNumber) : field.value);
      refresh();
    };
    return field;
  }

  function button(label, action) {
    const element = document.createElement("button");
    element.textContent = label;
    element.onclick = action;
    return element;
  }

  function rows() {
    $("control-rows").replaceChildren(...controls.map((point, i) => {
      const id = `P${i + 1}`;
      const row = document.createElement("tr");
      const role = document.createElement("select");
      role.setAttribute("aria-label", `${id} role`);
      role.append(new Option("Fit", "fit"), new Option("Check", "check"));
      role.value = point.role;
      role.onchange = () => { point.role = role.value; refresh(); };
      const values = [
        `${id} · ${point.pixel.map(v => v.toFixed(1)).join(", ")} px`,
        input("number", point.lonlat[0], `${id} longitude`, v => point.lonlat[0] = v),
        input("number", point.lonlat[1], `${id} latitude`, v => point.lonlat[1] = v),
        role,
        input("text", point.note, `${id} source or note`, v => point.note = v),
        "—"
      ];
      for (const value of values) row.insertCell().append(value);
      row.insertCell().append(button(`Move ${id}`, () => arm(i)), button(`Remove ${id}`, () => {
        controls.splice(i, 1); arm(null); rows(); refresh();
      }));
      return row;
    }));
  }

  function arm(index) {
    moving = index;
    updateReview();
    $("add-control").setAttribute("aria-pressed", String(index === controls.length));
    $("add-control").textContent = index === controls.length ? "Cancel marking" : "Mark control on PDF";
    $("control-instructions").textContent = index === null ? "" : `Click the PDF to place P${index + 1}.`;
    repaint();
  }

  function drawPreview(ring, previous, hull) {
    svg.replaceChildren();
    const all = [...ring, ...previous, ...hull, ...controls.map(p => p.lonlat)];
    const minX = Math.min(...all.map(p => p[0])), maxX = Math.max(...all.map(p => p[0]));
    const minY = Math.min(...all.map(p => p[1])), maxY = Math.max(...all.map(p => p[1]));
    const scale = Math.min(340 / (maxX - minX), 175 / (maxY - minY));
    const pos = ([x, y]) => [200 + (x - (minX + maxX) / 2) * scale, 113 - (y - (minY + maxY) / 2) * scale];
    function shape(type, attrs, label) {
      const element = document.createElementNS("http://www.w3.org/2000/svg", type);
      for (const [key, value] of Object.entries(attrs)) element.setAttribute(key, value);
      if (label) element.textContent = label;
      svg.append(element);
    }
    const polygon = (p, stroke, fill, dash = "") =>
      shape("polygon", {points: p.map(pos).join(" "), stroke, fill, "stroke-dasharray": dash, "stroke-width": 2});
    polygon(hull, "#718390", "none", "3 4");
    if (previous.length) polygon(previous, "#0065a8", "none", "5 4");
    polygon(ring, "#d74616", "#d7461620");
    controls.forEach((p, i) => {
      const [x, y] = pos(p.lonlat);
      if (p.role === "fit") shape("circle", {cx: x, cy: y, r: 3, fill: "#104f76"});
      else shape("rect", {x: x - 3, y: y - 3, width: 6, height: 6, fill: "#674286"});
      shape("text", {x: x + 5, y: y - 4, "font-size": 10}, `P${i + 1}`);
    });
    shape("text", {x: 12, y: 227, "font-size": 11},
      `Lon ${minX.toFixed(3)} to ${maxX.toFixed(3)}° · Lat ${minY.toFixed(3)} to ${maxY.toFixed(3)}°`);
  }

  function refresh() {
    const {vertices, crop} = context();
    result = null;
    let message;
    try {
      const project = fitAffine(controls);
      const ring = geographicRing(vertices, project);
      const quality = diagnostics(controls, vertices, project);
      const previous = baseline.length ? vertices.map(fitAffine(baseline)) : [];
      drawPreview(ring, previous, fitHull(controls).map(project));
      const fit = controls.filter(p => p.role === "fit");
      const checks = controls.filter(p => p.role === "check" && !fit.some(f =>
        f.pixel.join() === p.pixel.join() || f.lonlat.join() === p.lonlat.join())).length;
      const outsideCrop = controls.some(({pixel: [x, y]}) => x < crop.x || y < crop.y ||
        x > crop.x + crop.width || y > crop.y + crop.height);
      result = {ring, quality, checks, outsideCrop};
      const checkStatus = checks
        ? `${checks} check point(s) excluded from the fit. Review their errors above.`
        : "No independent check points. If you have an extra known location, set its role to Check.";
      message = `Affine fit in WGS 84 degrees. ${checkStatus} ${quality.outside} of ${vertices.length} vertices outside the fit-point boundary (extrapolated).`;
      if (outsideCrop) {
        message += " Some controls are outside the visible crop. Select a larger panel to inspect them.";
      }
    } catch (error) {
      message = error.message;
    }
    $("calibration-result").textContent = message;
    resetReview();
    updateReview();
    svg.toggleAttribute("hidden", !result);
    $("geo-legend").hidden = !result;
    [...$("control-rows").rows].forEach((row, i) => {
      row.cells[5].textContent = result ? result.quality.errors[i].toFixed(2) : "—";
    });
    repaint();
  }

  function resetReview() {
    for (const item of Object.values(reviewItems)) item.checked = false;
  }

  function updateReview() {
    const reviewer = $("reviewer").value.trim();
    const note = $("review-note").value.trim();
    const outside = result?.quality.outside ?? 0;
    const reason = !result ? "Complete a valid fit first."
      : !result.checks ? "Add a Check point at a known location distinct from the Fit points."
      : result.outsideCrop ? "All controls must be visible in the selected panel."
      : moving !== null ? "Finish or cancel the control point placement."
      : "";
    const items = Object.values(reviewItems);
    for (const item of items) item.disabled = Boolean(reason);
    const remaining = items.filter(item => !item.checked).length;
    $("review-note-label").textContent = outside
      ? `${outside} vertices are outside the Fit boundary. Which part did you check, and what reference supports its location? (required)`
      : "Additional review note (optional)";
    const pending = reason || (!reviewer ? "Enter your reviewer name or ID."
      : remaining ? `Complete the remaining checklist items (${remaining}).`
      : outside && !note ? "Add a note about the part outside the Fit boundary and the reference you used."
      : "");
    $("save-calibration").disabled = $("save-geojson").disabled = Boolean(pending);
    $("review-status").textContent = pending || "Checklist complete. Both GeoJSON files are ready to download.";
  }

  function load(data) {
    const {filename, page, fingerprint} = context();
    if (data && data.pdf_page !== page) {
      throw Error(`This calibration is for PDF page ${data.pdf_page}. The open page is ${page}.`);
    }
    if (data && (data.pdf_sha256 ? data.pdf_sha256 !== fingerprint : data.pdf_file !== filename)) {
      throw Error(`This calibration uses a different PDF copy. Open the PDF used to create it (${data.pdf_file}).`);
    }
    const loaded = data ? readControls(data, dpi) : [];
    baseline = [];
    try {
      fitAffine(loaded);
      baseline = structuredClone(loaded);
    } catch { /* An incomplete saved calibration remains editable. */ }
    controls = loaded;
    $("reviewer").value = "";
    $("review-note").value = "";
    $("calibration-note").value = data?.note ?? data?.source_projection_and_datum ?? "";
    arm(null); rows(); refresh();
  }

  function snapshot() {
    const {filename, page, fingerprint} = context();
    const reviewed = !$("save-geojson").disabled;
    return {
      pdf_file: filename, pdf_page: page, pdf_sha256: fingerprint, render_dpi: dpi,
      coordinate_space: "PDF page pixels, top-left origin", model: "affine", target_crs: "OGC:CRS84",
      status: reviewed ? "reviewed" : "provisional", controls, note: $("calibration-note").value,
      ...(reviewed ? {review: {
        reviewer: $("reviewer").value.trim(), date: new Date().toISOString(), note: $("review-note").value.trim(),
        checklist: Object.fromEntries(Object.entries(reviewItems).map(([key, item]) => [key, item.checked]))
      }} : {}),
      ...(result ? {diagnostics: result.quality} : {})
    };
  }

  $("add-control").onclick = () => arm(moving === controls.length ? null : controls.length);
  $("reviewer").oninput = $("calibration-note").oninput = () => {
    resetReview();
    updateReview();
  };
  $("review-note").oninput = updateReview;
  for (const item of Object.values(reviewItems)) item.onchange = updateReview;
  function exportGeoJSON(kind, build) {
    updateReview();
    if ($("save-geojson").disabled) return;
    const state = context();
    const calibration = snapshot();
    const content = {type: "FeatureCollection", tracer_export: kind, ...build(state, calibration)};
    download(`${state.stem}_${kind}.geojson`, JSON.stringify(content, null, 2), "application/geo+json");
  }

  $("save-geojson").onclick = () => exportGeoJSON("study-area", ({metadata, vertices, crop}, calibration) => ({
    features: [{
      type: "Feature",
      properties: {
        ...metadata, crop, vertices: [...vertices, vertices[0]], calibration,
        render_dpi: dpi, coordinate_space: calibration.coordinate_space,
        status: "reviewed", geographic_status: "reviewed"
      },
      geometry: {type: "Polygon", coordinates: [result.ring]}
    }]
  }));
  $("save-calibration").onclick = () => exportGeoJSON("calibration", (_state, calibration) => ({
    calibration,
    features: controls.map(({pixel, lonlat, role, note}, i) => ({
      type: "Feature",
      properties: {
        point: `P${i + 1}`, role, pixel_x: pixel[0], pixel_y: pixel[1],
        note, error_km: result.quality.errors[i], reviewer: calibration.review.reviewer
      },
      geometry: {type: "Point", coordinates: lonlat}
    }))
  }));

  return {
    load, refresh, cancelPlacement: () => arm(null),
    isPlacing: () => moving !== null,
    place(pixel) {
      if (moving === controls.length) controls.push({pixel, lonlat: [null, null], role: "fit", note: ""});
      else controls[moving].pixel = pixel;
      arm(null); rows(); refresh();
    },
    paint(ink, crop, width) {
      if (!crop) return;
      controls.forEach(({pixel: [x, y], role}, i) => {
        ink.fillStyle = role === "fit" ? "#104f76" : "#674286";
        ink.font = `${width * 5}px system-ui`;
        ink.beginPath();
        ink.arc(x - crop.x, y - crop.y, width * 1.8, 0, Math.PI * 2);
        ink.fill();
        ink.fillText(`P${i + 1}`, x - crop.x + width * 2, y - crop.y - width * 2);
      });
    }
  };
}
