import { initializeApp } from "https://www.gstatic.com/firebasejs/12.0.0/firebase-app.js";
import {
  getAuth,
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut,
} from "https://www.gstatic.com/firebasejs/12.0.0/firebase-auth.js";
import {
  collection,
  doc,
  getDocs,
  getFirestore,
  limit,
  orderBy,
  query,
  updateDoc,
} from "https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js";

import { firebaseConfig } from "./firebase-config.js";
import { renderWalkImage } from "./snapshot.js";

const el = (id) => document.getElementById(id);
const show = (id, visible) => el(id).toggleAttribute("hidden", !visible);

const DEFAULT_ROUTE_COLOR = "#D9293D";
/// Capped because every document read counts against the free Firestore quota.
const HISTORY_LIMIT = 200;

function fail(message) {
  el("error-message").textContent = message;
  for (const id of ["loading", "signed-out", "history", "empty"]) show(id, false);
  show("error", true);
}

if (firebaseConfig.apiKey === "REPLACE_ME") {
  fail("web/firebase-config.js todavía tiene los valores de ejemplo.");
  throw new Error("Firebase is not configured");
}

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

let walks = [];
let selectedId = null;
let uid = null;

// --- formatting, kept in step with WalkFormatting.swift -------------------

const metres = (v) => (v < 1000 ? `${Math.round(v)} m` : `${(v / 1000).toFixed(2)} km`);

function duration(seconds) {
  const total = Math.round(seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

/// Pace only means something once enough ground is covered, same rule the app
/// applies before it shows a number.
function pace(distance, movingTime) {
  if (distance < 50 || movingTime <= 0) return "--";
  const perKm = movingTime / (distance / 1000);
  return `${Math.floor(perKm / 60)}:${String(Math.round(perKm % 60)).padStart(2, "0")} /km`;
}

const longDate = (d) =>
  d.toLocaleString("es-AR", { dateStyle: "long", timeStyle: "short" });
const shortDate = (d) => d.toLocaleDateString("es-AR", { dateStyle: "medium" });

const fallbackName = (walk) => `Caminata del ${shortDate(walk.startedAt)}`;
const displayName = (walk) => (walk.name?.trim() ? walk.name.trim() : fallbackName(walk));

// --- the map --------------------------------------------------------------

let map = null;
let drawn = null;

function ensureMap() {
  if (map) return map;
  map = L.map("map", { zoomControl: true, attributionControl: true });
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: "© OpenStreetMap",
  }).addTo(map);
  return map;
}

function drawRoute(walk) {
  const m = ensureMap();
  if (drawn) drawn.remove();
  drawn = null;
  if (walk.coordinates.length === 0) return;

  const colour = walk.routeColor || DEFAULT_ROUTE_COLOR;
  document.documentElement.style.setProperty("--route", colour);

  const layer = L.layerGroup();
  L.polyline(walk.coordinates, { color: "#ffffff", weight: 9, opacity: 0.95 }).addTo(layer);
  const line = L.polyline(walk.coordinates, {
    color: colour,
    weight: 4.5,
    className: "route-line",
  }).addTo(layer);

  const marker = (point, fill) =>
    L.circleMarker(point, {
      radius: 7,
      color: "#ffffff",
      weight: 3,
      fillColor: fill,
      fillOpacity: 1,
    });
  marker(walk.coordinates[0], "#21a659").addTo(layer);
  if (walk.coordinates.length > 1) {
    marker(walk.coordinates.at(-1), "#1f3347").addTo(layer);
  }

  layer.addTo(m);
  drawn = layer;
  m.fitBounds(L.latLngBounds(walk.coordinates), { padding: [40, 40] });

  // The dash animation needs the path's own length, which only exists once
  // Leaflet has put it in the DOM.
  requestAnimationFrame(() => {
    m.invalidateSize();
    const path = line.getElement();
    if (path) path.style.setProperty("--len", path.getTotalLength());
  });
}

// --- data -----------------------------------------------------------------

/// `route` arrives as a flat [lat, lng, ...] array, which is how it is
/// written: Firestore cannot nest an array inside an array.
function toWalk(snapshot) {
  const data = snapshot.data();
  const flat = data.route ?? [];
  const coordinates = [];
  for (let i = 0; i + 1 < flat.length; i += 2) coordinates.push([flat[i], flat[i + 1]]);

  return {
    id: snapshot.id,
    name: data.name ?? null,
    routeColor: /^#[0-9a-f]{6}$/i.test(data.routeColor ?? "") ? data.routeColor : null,
    startedAt: data.startedAt?.toDate() ?? new Date(0),
    endedAt: data.endedAt?.toDate() ?? null,
    distance: data.distance ?? 0,
    movingTime: data.movingTime ?? 0,
    elevationGain: data.elevationGain ?? 0,
    pointCount: data.pointCount ?? 0,
    coordinates,
  };
}

async function loadWalks(userId) {
  const snapshot = await getDocs(
    query(
      collection(db, "users", userId, "walks"),
      orderBy("startedAt", "desc"),
      limit(HISTORY_LIMIT),
    ),
  );
  return snapshot.docs.map(toWalk);
}

let saveTimer = null;

function hint(text) {
  const node = el("save-hint");
  node.textContent = text;
  node.classList.add("show");
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => node.classList.remove("show"), 1800);
}

/// Saves the typed name. An empty field clears it back to the date, which is
/// why it writes null rather than refusing.
async function saveName(walkId, raw) {
  const walk = walks.find((w) => w.id === walkId);
  if (!walk) return;

  const name = raw.trim().slice(0, 80);
  const next = name === "" ? null : name;
  if (next === walk.name) return;

  try {
    await updateDoc(doc(db, "users", uid, "walks", walkId), { name: next });
    walk.name = next;
    const row = document.querySelector(`.walk-list li[data-id="${walkId}"] .row-name`);
    if (row) row.textContent = displayName(walk);
    hint("Guardado");
  } catch (error) {
    hint("No se pudo guardar");
    console.error(error);
  }
}

// --- rendering ------------------------------------------------------------

function openStats(walk) {
  const elapsed = walk.endedAt ? (walk.endedAt - walk.startedAt) / 1000 : walk.movingTime;
  el("stats-title").textContent = displayName(walk);
  el("stats-body").innerHTML = [
    ["Distancia", metres(walk.distance)],
    ["Duración", duration(elapsed)],
    ["En movimiento", duration(walk.movingTime)],
    ["Ritmo", pace(walk.distance, walk.movingTime)],
    ["Desnivel", `${Math.round(walk.elevationGain)} m`],
    ["Posiciones", String(walk.pointCount)],
  ]
    .map(([k, v]) => `<div class="stat"><dt>${k}</dt><dd>${v}</dd></div>`)
    .join("");
  el("stats").showModal();
}

function select(id) {
  const walk = walks.find((w) => w.id === id);
  if (!walk) return;
  selectedId = id;

  for (const node of document.querySelectorAll(".walk-list li")) {
    const on = node.dataset.id === id;
    node.classList.toggle("selected", on);
    node.setAttribute("aria-current", on ? "true" : "false");
  }

  el("walk-name").value = walk.name ?? "";
  el("walk-name").placeholder = fallbackName(walk);
  el("walk-date").textContent = longDate(walk.startedAt);
  drawRoute(walk);
}

function renderList() {
  const list = el("walk-list");
  list.innerHTML = "";
  el("walk-count").textContent = walks.length;

  for (const walk of walks) {
    const item = document.createElement("li");
    item.dataset.id = walk.id;
    item.tabIndex = 0;
    item.setAttribute("role", "button");

    const text = document.createElement("div");
    text.className = "row-text";
    const name = document.createElement("span");
    name.className = "row-name";
    name.textContent = displayName(walk);
    const date = document.createElement("span");
    date.className = "row-date";
    date.textContent = `${shortDate(walk.startedAt)} · ${metres(walk.distance)}`;
    text.append(name, date);

    const info = document.createElement("button");
    info.className = "row-info";
    info.type = "button";
    info.setAttribute("aria-label", `Ver los números de ${displayName(walk)}`);
    info.innerHTML =
      '<svg viewBox="0 0 24 24" class="icon"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 7.6v.5"/></svg>';
    info.addEventListener("click", (event) => {
      event.stopPropagation();
      openStats(walk);
    });

    item.append(text, info);
    item.addEventListener("click", () => select(walk.id));
    item.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        select(walk.id);
      }
    });
    list.append(item);
  }
}

// --- wiring ---------------------------------------------------------------

el("walk-name").addEventListener("change", (event) => saveName(selectedId, event.target.value));
el("walk-name").addEventListener("keydown", (event) => {
  if (event.key === "Enter") event.target.blur();
  if (event.key === "Escape") {
    const walk = walks.find((w) => w.id === selectedId);
    event.target.value = walk?.name ?? "";
    event.target.blur();
  }
});

el("download").addEventListener("click", async (event) => {
  const walk = walks.find((w) => w.id === selectedId);
  if (!walk) return;

  const button = event.currentTarget;
  button.disabled = true;
  const label = button.lastChild;
  const original = label.textContent;
  label.textContent = " Generando…";

  try {
    const blob = await renderWalkImage(walk.coordinates, {
      color: walk.routeColor || DEFAULT_ROUTE_COLOR,
      caption: displayName(walk),
    });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${displayName(walk).replace(/[^\p{L}\p{N}]+/gu, "-").toLowerCase()}.png`;
    link.click();
    URL.revokeObjectURL(url);
  } catch (error) {
    hint("No se pudo generar la imagen");
    console.error(error);
  } finally {
    label.textContent = original;
    button.disabled = false;
  }
});

el("sign-in").addEventListener("click", async () => {
  try {
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (error) {
    // Closing the popup is a decision, not a failure worth a red screen.
    if (error.code === "auth/popup-closed-by-user") return;
    fail(error.message);
  }
});

el("sign-out").addEventListener("click", () => signOut(auth));

onAuthStateChanged(auth, async (user) => {
  show("error", false);
  el("account").toggleAttribute("hidden", !user);
  uid = user?.uid ?? null;

  if (!user) {
    for (const id of ["loading", "history", "empty"]) show(id, false);
    show("signed-out", true);
    return;
  }

  el("account-name").textContent = user.displayName ?? user.email ?? "";
  for (const id of ["signed-out", "history", "empty"]) show(id, false);
  show("loading", true);

  try {
    walks = await loadWalks(user.uid);
    show("loading", false);

    if (walks.length === 0) {
      show("empty", true);
      return;
    }

    renderList();
    show("history", true);

    // A ?walk=<id> link comes from the app's export screen. An unknown id --
    // an old link, or one from somebody else's phone -- falls back to the
    // most recent walk rather than an empty page.
    const asked = new URLSearchParams(location.search).get("walk");
    const wanted = asked && walks.some((w) => w.id === asked) ? asked : walks[0].id;
    select(wanted);
    if (wanted !== walks[0].id) {
      document
        .querySelector(`.walk-list li[data-id="${wanted}"]`)
        ?.scrollIntoView({ block: "nearest" });
    }
  } catch (error) {
    fail(error.message);
  }
});
