/*
  Renders a walk to a PNG: map tiles, the route on top, start and end markers.

  Done by hand rather than with a screenshot library because the maths is the
  standard slippy-map projection and doing it directly means no dependency, no
  reading of Leaflet's internals, and an image whose size is chosen here rather
  than dictated by the size of the browser window.
*/

const TILE = 256;
const MAX_ZOOM = 19;
const PADDING = 0.08;

const lonToX = (lon, z) => ((lon + 180) / 360) * 2 ** z;

const latToY = (lat, z) => {
  const r = (lat * Math.PI) / 180;
  return ((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * 2 ** z;
};

function loadTile(url) {
  return new Promise((resolve) => {
    const img = new Image();
    // OpenStreetMap serves tiles with CORS headers, which is what keeps the
    // canvas untainted and lets it be exported at all.
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = url;
  });
}

/// Picks the closest zoom at which the whole route still fits the canvas.
function fitZoom(bounds, width, height) {
  for (let z = MAX_ZOOM; z >= 1; z -= 1) {
    const w = (lonToX(bounds.east, z) - lonToX(bounds.west, z)) * TILE;
    const h = (latToY(bounds.south, z) - latToY(bounds.north, z)) * TILE;
    if (w <= width * (1 - PADDING * 2) && h <= height * (1 - PADDING * 2)) return z;
  }
  return 1;
}

function boundsOf(coordinates) {
  const lats = coordinates.map((c) => c[0]);
  const lons = coordinates.map((c) => c[1]);
  return {
    north: Math.max(...lats),
    south: Math.min(...lats),
    west: Math.min(...lons),
    east: Math.max(...lons),
  };
}

/**
 * @param {[number, number][]} coordinates lat/lon pairs
 * @param {{ color?: string, caption?: string }} options
 * @returns {Promise<Blob>}
 */
export async function renderWalkImage(coordinates, { color = "#D9293D", caption = "" } = {}) {
  if (coordinates.length === 0) throw new Error("La caminata no tiene recorrido para dibujar.");

  const bounds = boundsOf(coordinates);
  // A tall route gets a tall picture; a wide one gets a wide picture. Fitting
  // a vertical walk into a landscape frame wastes most of the image on map.
  const spanX = Math.max(bounds.east - bounds.west, 1e-6);
  const spanY = Math.max(bounds.north - bounds.south, 1e-6);
  const portrait = spanY > spanX * 1.15;
  const width = portrait ? 1200 : 1600;
  const height = portrait ? 1600 : 1200;

  const zoom = fitZoom(bounds, width, height);
  const scale = 2 ** zoom;

  const centreX = (lonToX(bounds.west, zoom) + lonToX(bounds.east, zoom)) / 2;
  const centreY = (latToY(bounds.north, zoom) + latToY(bounds.south, zoom)) / 2;

  // Top-left of the canvas, in tile units.
  const originX = centreX - width / 2 / TILE;
  const originY = centreY - height / 2 / TILE;

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");

  ctx.fillStyle = "#e8e3d8";
  ctx.fillRect(0, 0, width, height);

  const firstX = Math.floor(originX);
  const lastX = Math.floor(originX + width / TILE);
  const firstY = Math.floor(originY);
  const lastY = Math.floor(originY + height / TILE);
  const limit = 2 ** zoom;

  const jobs = [];
  for (let x = firstX; x <= lastX; x += 1) {
    for (let y = firstY; y <= lastY; y += 1) {
      if (y < 0 || y >= limit) continue;
      const wrapped = ((x % limit) + limit) % limit;
      jobs.push(
        loadTile(`https://tile.openstreetmap.org/${zoom}/${wrapped}/${y}.png`).then((img) => {
          if (img) ctx.drawImage(img, (x - originX) * TILE, (y - originY) * TILE, TILE, TILE);
        }),
      );
    }
  }
  await Promise.all(jobs);

  const points = coordinates.map(([lat, lon]) => [
    (lonToX(lon, zoom) - originX) * TILE,
    (latToY(lat, zoom) - originY) * TILE,
  ]);

  ctx.lineCap = "round";
  ctx.lineJoin = "round";

  const stroke = (colour, lineWidth) => {
    ctx.beginPath();
    points.forEach(([x, y], i) => (i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)));
    ctx.strokeStyle = colour;
    ctx.lineWidth = lineWidth;
    ctx.stroke();
  };

  // A pale outline under the line keeps it readable over parks, water and
  // dense street grids alike -- the same trick the phone uses.
  stroke("rgba(255,255,255,0.95)", 15);
  stroke(color, 8);

  const marker = (point, fill) => {
    ctx.beginPath();
    ctx.arc(point[0], point[1], 13, 0, Math.PI * 2);
    ctx.fillStyle = "#ffffff";
    ctx.fill();
    ctx.beginPath();
    ctx.arc(point[0], point[1], 9, 0, Math.PI * 2);
    ctx.fillStyle = fill;
    ctx.fill();
  };
  marker(points[0], "#21a659");
  if (points.length > 1) marker(points[points.length - 1], "#1f3347");

  // Required by the OpenStreetMap tile licence, and it travels with the file.
  const note = caption ? `${caption}  ·  © OpenStreetMap` : "© OpenStreetMap contributors";
  ctx.font = "500 22px ui-sans-serif, system-ui, sans-serif";
  const textWidth = ctx.measureText(note).width;
  ctx.fillStyle = "rgba(255,255,255,0.88)";
  ctx.fillRect(0, height - 42, textWidth + 32, 42);
  ctx.fillStyle = "#33413a";
  ctx.fillText(note, 16, height - 15);

  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("No se pudo generar la imagen."))),
      "image/png",
    );
  });
}
