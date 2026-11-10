import * as pdfjs from "./vendor/build/pdf.mjs";
import { validRing } from "./geometry.mjs";
import { createCalibration } from "./calibration-ui.mjs";

pdfjs.GlobalWorkerOptions.workerSrc = new URL("./vendor/build/pdf.worker.mjs", import.meta.url).href;
const $ = id => document.getElementById(id);
const image = $("image"), overlay = $("overlay");
const ink = overlay.getContext("2d");
const previewDpi = 125, detailDpi = 600;
let pdf, filename, fingerprint, page = 1, stage = 0, busy = false, crop, corner, points = [];
let saved = [], selected = -1, reference = [];
let editing = false, activeVertex = -1, insertPoint = false, drag = null, history = [];
const pagePoint = ([x, y]) => [x + crop.x, y + crop.y].map(v => +v.toFixed(8));
const outputStem = () => `${filename.replace(/\.pdf$/i, "")}_page${page}_panel_${crop.x}_${crop.y}_${crop.width}x${crop.height}`;
const calibration = createCalibration({
  dpi: detailDpi,
  context: () => ({
    filename, page, fingerprint, crop, vertices: crop ? points.map(pagePoint) : [],
    stem: crop ? outputStem() : "",
    metadata: {...saved[selected], pdf_file: filename, pdf_page: page}
  }),
  repaint: marks,
  download
});

const headings = ["Choose the PDF and page", "Select the map panel", "Trace the outline", "Calibrate and save"];
const guidance = [
  "Choose a PDF. Use the arrows or the page number to find the map, then click Open page.",
  "Click two opposite corners around the map. Leave some space around its boundary.",
  "Click along the boundary in order. Use Undo point to correct the last click. Close the outline when finished.",
  "Check the orange outline. Complete the geographic review to export the calibration points and study area."
];

function status(message = "", error = false) {
  $("status").textContent = message;
  $("status").classList.toggle("error", error);
}

function showStep(next) {
  stage = next;
  $("heading").textContent = `Step ${stage + 1} of 4 · ${headings[stage]}`;
  $("instructions").textContent = guidance[stage];
  [...$("steps").children].forEach((item, i) => {
    if (i === stage) item.setAttribute("aria-current", "step");
    else item.removeAttribute("aria-current");
  });
  ["file", "crop", "draw", "review"].forEach((name, i) => $(name + "-tools").hidden = stage !== i);
  $("zoom-tools").hidden = stage < 2;
  updateEditor();
  $("calibration").hidden = stage !== 3;
  overlay.style.pointerEvents = stage >= 1 ? "auto" : "none";
}

function fit(resetScroll = false) {
  if ($("viewport").hidden) return;
  const view = $("viewport"), zoom = stage >= 2 ? Number($("zoom").value) : 1;
  const scale = Math.min((view.clientWidth - 12) / image.width, (view.clientHeight - 12) / image.height) * zoom;
  $("map").style.width = `${Math.max(1, image.width * scale)}px`;
  $("map").style.height = `${Math.max(1, image.height * scale)}px`;
  if (resetScroll) { view.scrollTop = 0; view.scrollLeft = 0; }
}

function marks() {
  ink.clearRect(0, 0, overlay.width, overlay.height);
  const width = 2.5 * overlay.width / Math.max(1, overlay.getBoundingClientRect().width);
  for (const [vertices, colour, dashed] of [[reference, "#0065a8", true], [points, "#d74616", false]]) {
    if (!vertices.length) continue;
    ink.strokeStyle = ink.fillStyle = colour;
    ink.lineWidth = width;
    ink.setLineDash(dashed ? [3 * width, 2 * width] : []);
    ink.beginPath();
    ink.moveTo(...vertices[0]);
    vertices.slice(1).forEach(p => ink.lineTo(...p));
    if ((stage === 3 || editing) && !dashed) ink.closePath();
    ink.stroke();
    if (!dashed) vertices.forEach((p, i) => {
      ink.fillStyle = i === activeVertex ? "#13354f" : colour;
      ink.beginPath(); ink.arc(...p, 1.4 * width, 0, 2 * Math.PI); ink.fill();
    });
  }
  if (corner) {
    ink.fillStyle = "#d74616";
    ink.fillRect(corner[0] - width, corner[1] - width, width * 2, width * 2);
  }
  if (stage === 3) calibration.paint(ink, crop, width);
}

// Render the crop from the PDF, then use CSS zoom to inspect it without changing saved pixels.
async function render(dpi, region = null) {
  const pdfPage = await pdf.getPage(page);
  const view = pdfPage.getViewport({ scale: dpi / 72 });
  image.width = overlay.width = region?.width ?? Math.ceil(view.width);
  image.height = overlay.height = region?.height ?? Math.ceil(view.height);
  await pdfPage.render({
    canvas: image, viewport: view,
    transform: region ? [1, 0, 0, 1, -region.x, -region.y] : undefined
  }).promise;
  $("viewport").hidden = false;
  $("empty").hidden = true;
  fit(true);
  marks();
}

async function attempt(action) {
  if (busy) return;
  busy = true;
  status();
  try { await action(); }
  catch (error) { status(error.message, true); }
  finally { busy = false; }
}

function resetOutline() {
  corner = null; crop = null; points = []; saved = []; selected = -1; reference = [];
  clearEditor();
  $("reference").value = "";
  $("reference-choice").hidden = true;
  $("zoom").value = "1";
  $("load-calibration").value = "";
  calibration.load(null);
}

async function preview(n, nextStage) {
  if (!pdf) throw Error("Choose a PDF first.");
  if (!Number.isInteger(n) || n < 1 || n > pdf.numPages) {
    throw Error(`Enter a whole page number from 1 to ${pdf.numPages}.`);
  }
  page = n;
  $("page").value = n;
  resetOutline();
  await render(previewDpi);
  showStep(nextStage); fit(true); marks();
}

$("pdf").onchange = () => attempt(async () => {
  const file = $("pdf").files[0];
  if (!file) return;
  status("Opening PDF locally…");
  const base = new URL("./vendor/", import.meta.url).href;
  const data = await file.arrayBuffer();
  const digest = await crypto.subtle.digest("SHA-256", data);
  fingerprint = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
  pdf = await pdfjs.getDocument({
    data, cMapUrl: base + "cmaps/", cMapPacked: true,
    standardFontDataUrl: base + "standard_fonts/", wasmUrl: base + "wasm/"
  }).promise;
  filename = file.name;
  $("filename").textContent = filename;
  $("page").max = pdf.numPages;
  $("page-count").textContent = `of ${pdf.numPages}`;
  await preview(1, 0);
  status(`Loaded ${pdf.numPages} pages. Find the map and click Open page.`);
});

$("previous").onclick = () => attempt(() => preview(Math.max(1, page - 1), 0));
$("next").onclick = () => attempt(() => preview(Math.min(pdf?.numPages ?? 1, page + 1), 0));
$("open").onclick = () => attempt(() => preview($("page").valueAsNumber, 1));
$("page").onkeydown = event => { if (event.key === "Enter") $("open").click(); };
$("back-file").onclick = () => attempt(() => preview(page, 0));
$("back-page").onclick = () => attempt(() => preview(page, 1));
$("zoom").onchange = () => { fit(); marks(); };
new ResizeObserver(() => { fit(); marks(); }).observe($("viewport"));

overlay.onclick = event => attempt(async () => {
  const point = imagePoint(event);
  if (stage === 1 && !corner) {
    corner = point; marks(); status("First corner marked. Click the opposite corner.");
  } else if (stage === 1) {
    const factor = detailDpi / previewDpi;
    const x = Math.floor(Math.min(corner[0], point[0]) * factor);
    const y = Math.floor(Math.min(corner[1], point[1]) * factor);
    const width = Math.ceil(Math.max(corner[0], point[0]) * factor) - x;
    const height = Math.ceil(Math.max(corner[1], point[1]) * factor) - y;
    corner = null; marks();
    if (width < 20 || height < 20) throw Error("Select a larger panel with two new clicks.");
    crop = {x, y, width, height};
    await render(detailDpi, crop);
    showStep(2); fit(true); marks();
  } else if (stage === 2 && !editing) {
    remember();
    points.push(point); marks(); status(`${points.length} vertices marked.`);
  } else if (stage === 3 && calibration.isPlacing()) {
    calibration.place(pagePoint(point));
  }
});

function showReference() {
  const index = Number($("reference-choice").value), record = saved[index];
  const dpi = record?.render_dpi ?? (/125 dpi/.test(record?.coordinate_space ?? "") ? 125 : null);
  if (!record || !Number.isFinite(dpi) || dpi <= 0 ||
      !Array.isArray(record.vertices) || record.vertices.length < 4 ||
      !record.vertices.every(p => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite))) {
    throw Error("This saved outline has invalid vertices or no recognised render resolution.");
  }
  if (record.pdf_file && record.pdf_file !== filename) throw Error("This outline names a different PDF.");
  selected = index;
  reference = record.vertices.map(([x, y]) => [x * detailDpi / dpi - crop.x, y * detailDpi / dpi - crop.y]);
  updateEditor(); marks();
  const outside = reference.some(([x, y]) => x < 0 || y < 0 || x > crop.width || y > crop.height);
  status(outside ? "Part of the blue reference lies outside this crop." : "Blue dashed line: saved reference.");
}

$("reference").onchange = () => attempt(async () => {
  const file = $("reference").files[0];
  if (!file) return;
  const data = JSON.parse(await file.text());
  const loaded = data?.tracer_export === "study-area" ? data.features?.map(feature => feature.properties) : data;
  if (!Array.isArray(loaded)) throw Error("Choose a REDUCE outline JSON or a study-area GeoJSON exported by this tracer.");
  const matching = loaded.map((record, i) => [record, i]).filter(([record]) => record?.pdf_page === page);
  if (!matching.length) throw Error(`The JSON has no saved outline for page ${page}.`);
  saved = loaded; selected = -1; reference = []; marks();
  const choice = $("reference-choice");
  choice.replaceChildren(...matching.map(([record, i]) =>
    new Option([`Outline ${i + 1}`, record.site, record.buffer_area_multiplier && `${record.buffer_area_multiplier}× area`]
      .filter(Boolean).join(" · "), i)
  ));
  choice.hidden = false;
  showReference();
});

$("reference-choice").onchange = () => attempt(() => {
  selected = -1; reference = []; marks(); showReference();
});
// Convert screen clicks to crop pixels, independently of the current zoom.
function imagePoint(event) {
  const rect = overlay.getBoundingClientRect();
  return [(event.clientX - rect.left) * overlay.width / rect.width,
          (event.clientY - rect.top) * overlay.height / rect.height];
}

function clearEditor() {
  editing = false; activeVertex = -1; insertPoint = false; drag = null; history = [];
  updateEditor();
}

function updateEditor() {
  overlay.style.touchAction = editing && stage === 2 ? "none" : "manipulation";
  $("edit-reference").disabled = selected < 0 || editing;
  $("add-point").hidden = $("delete-point").hidden = !editing;
  $("add-point").setAttribute("aria-pressed", String(insertPoint));
  $("delete-point").disabled = activeVertex < 0 || points.length <= 3;
  $("undo").disabled = !history.length;
  $("reference").disabled = $("reference-choice").disabled = editing;
  if (stage === 2) {
    $("instructions").textContent = editing
      ? "Drag a vertex to move it. To insert a vertex, choose Add point and click near an edge. Select a vertex to delete it. Use Undo to reverse a change."
      : guidance[2];
  }
}

function remember() {
  history.push(points.map(p => [...p]));
  updateEditor();
}

// Copy the saved ring without its duplicate closing vertex.
$("edit-reference").onclick = () => attempt(async () => {
  if (selected < 0 || (points.length && !window.confirm("Replace the current outline with the saved outline?"))) return;
  calibration.load(saved[selected].calibration ?? null);
  points = reference.map(p => [...p]);
  if (points[0]?.every((v, i) => v === points.at(-1)[i])) points.pop();
  editing = true; history = []; activeVertex = -1;
  updateEditor(); marks();
  status("Blue: original outline. Orange: editable copy.");
});

$("add-point").onclick = () => {
  insertPoint = !insertPoint;
  updateEditor();
  status(insertPoint ? "Click near an edge to insert a point." : "Drag a vertex to move it.");
};

function nearestEdge(point) {
  let best = {distance: Infinity};
  for (let i = 0; i < points.length; i++) {
    const a = points[i], b = points[(i + 1) % points.length];
    const dx = b[0] - a[0], dy = b[1] - a[1];
    const length = dx * dx + dy * dy;
    if (!length) continue;
    const t = Math.max(0, Math.min(1, ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / length));
    const distance = Math.hypot(point[0] - a[0] - t * dx, point[1] - a[1] - t * dy);
    if (distance < best.distance) best = {index: i, distance, t};
  }
  return best;
}

// Handle selection, insertion and dragging only when editing an existing ring.
overlay.onpointerdown = event => {
  if (stage !== 2 || !editing || event.button !== 0) return;
  const point = imagePoint(event);
  const tolerance = 12 * overlay.width / overlay.getBoundingClientRect().width;
  if (insertPoint) {
    const edge = nearestEdge(point);
    if (edge.distance > tolerance || edge.t <= 0 || edge.t >= 1) {
      status("Click near the middle of an edge to add a vertex.", true); return;
    }
    remember();
    activeVertex = edge.index + 1;
    points.splice(activeVertex, 0, point);
    insertPoint = false;
  } else {
    const distances = points.map(p => Math.hypot(p[0] - point[0], p[1] - point[1]));
    activeVertex = distances.indexOf(Math.min(...distances));
    if (distances[activeVertex] > tolerance) activeVertex = -1;
    if (activeVertex >= 0) {
      drag = {id: event.pointerId, start: point, original: [...points[activeVertex]], moved: false};
      overlay.setPointerCapture(event.pointerId);
    }
  }
  updateEditor(); marks();
  status(activeVertex >= 0 ? "Vertex selected." : "Click or drag an orange vertex.");
};

overlay.onpointermove = event => {
  if (!drag || drag.id !== event.pointerId) return;
  const point = imagePoint(event);
  if (!drag.moved) { remember(); drag.moved = true; }
  points[activeVertex] = point.map((v, i) =>
    Math.min(i === 0 ? overlay.width : overlay.height, Math.max(0, drag.original[i] + v - drag.start[i])));
  marks();
};
overlay.onpointerup = overlay.onpointercancel = () => { drag = null; };

$("delete-point").onclick = () => {
  if (activeVertex < 0 || points.length <= 3) return;
  remember(); points.splice(activeVertex, 1); activeVertex = -1;
  updateEditor(); marks(); status("Vertex deleted.");
};

$("undo").onclick = () => {
  if (!history.length) return;
  points = history.pop(); activeVertex = -1; insertPoint = false;
  updateEditor(); marks(); status("Last change undone.");
};

$("clear").onclick = () => {
  if (editing && !window.confirm("Clear the editable outline and start a new trace?")) return;
  if (editing) clearEditor(); else remember();
  points = [];
  updateEditor(); marks(); status("Outline cleared.");
};

$("close-outline").onclick = () => {
  if (!validRing(points)) {
    status("Mark at least three distinct points and follow the boundary without crossing it.", true);
    return;
  }
  showStep(3); calibration.refresh(); status("Outline closed. Check it before downloading.");
};
$("edit").onclick = () => { calibration.cancelPlacement(); showStep(2); marks(); status(); };

$("load-calibration").onchange = () => attempt(async () => {
  const file = $("load-calibration").files[0];
  $("load-calibration").value = "";
  if (!file) return;
  calibration.cancelPlacement();
  const fileData = JSON.parse(await file.text());
  const data = fileData?.tracer_export === "calibration" ? fileData.calibration : fileData;
  if (Array.isArray(data) || data?.tracer_export === "study-area") {
    throw Error("This is an outline file. Use Back to editing, then Load reference JSON or GeoJSON to reopen it.");
  }
  if (!Array.isArray(data?.controls)) {
    throw Error("This file does not contain calibration control points.");
  }
  calibration.load(data);
  status("Calibration loaded. Review its points and projection assumptions.");
});

function download(name, content, type) {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const link = document.createElement("a");
  link.href = url; link.download = name; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  status(`Downloaded ${name}`);
}

showStep(0);
$("startup-help").hidden = true;
