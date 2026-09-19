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
  getDocs,
  getFirestore,
  limit,
  orderBy,
  query,
} from "https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js";

import { firebaseConfig } from "./firebase-config.js";

const el = (id) => document.getElementById(id);
const show = (id, visible) => el(id).toggleAttribute("hidden", !visible);

function fail(message) {
  el("error-message").textContent = message;
  for (const id of ["loading", "signed-out", "history", "empty"]) show(id, false);
  show("error", true);
}

if (firebaseConfig.apiKey === "REPLACE_ME") {
  fail(
    "web/firebase-config.js still has its placeholder values. Copy the real " +
      "ones out of the Firebase console under Project settings → Your apps → Web.",
  );
  throw new Error("Firebase is not configured");
}

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// --- formatting, kept in step with WalkFormatting.swift ------------------

const metres = (value) =>
  value < 1000 ? `${Math.round(value)} m` : `${(value / 1000).toFixed(2)} km`;

function duration(seconds) {
  const total = Math.round(seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

/// Pace is only meaningful once enough ground has been covered, same rule the
/// app applies before it shows a number.
function pace(distance, movingTime) {
  if (distance < 50 || movingTime <= 0) return "--";
  const perKm = movingTime / (distance / 1000);
  return `${Math.floor(perKm / 60)}:${String(Math.round(perKm % 60)).padStart(2, "0")} /km`;
}

const walkName = (date) =>
  date.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });

// --- the map ------------------------------------------------------------

let map = null;
let drawn = null;

/// OpenStreetMap tiles: no key, no account, no quota to blow through. The app
/// uses Apple's tiles for the emailed image, which is a different surface.
function ensureMap() {
  if (map) return map;
  map = L.map("map", { attributionControl: true });
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: "© OpenStreetMap contributors",
  }).addTo(map);
  return map;
}

function drawRoute(walk) {
  const m = ensureMap();
  if (drawn) {
    drawn.remove();
    drawn = null;
  }
  if (walk.coordinates.length === 0) return;

  const layer = L.layerGroup();
  L.polyline(walk.coordinates, { color: "#ffffff", weight: 8, opacity: 0.9 }).addTo(layer);
  L.polyline(walk.coordinates, { color: "#d92a3d", weight: 4 }).addTo(layer);

  const marker = (point, colour) =>
    L.circleMarker(point, {
      radius: 7,
      color: "#ffffff",
      weight: 3,
      fillColor: colour,
      fillOpacity: 1,
    });
  marker(walk.coordinates[0], "#22a65a").addTo(layer);
  if (walk.coordinates.length > 1) {
    marker(walk.coordinates[walk.coordinates.length - 1], "#1f3347").addTo(layer);
  }

  layer.addTo(m);
  drawn = layer;
  m.fitBounds(L.latLngBounds(walk.coordinates), { padding: [32, 32] });
  // The container is sized by CSS after the map is built, so Leaflet has to be
  // told to look again or it renders into a zero-height box.
  requestAnimationFrame(() => m.invalidateSize());
}

// --- data ---------------------------------------------------------------

/// `route` arrives as a flat [lat, lng, lat, lng, ...] array, which is how it
/// is written: Firestore cannot nest an array inside an array.
function toWalk(doc) {
  const data = doc.data();
  const flat = data.route ?? [];
  const coordinates = [];
  for (let i = 0; i + 1 < flat.length; i += 2) coordinates.push([flat[i], flat[i + 1]]);

  return {
    id: doc.id,
    startedAt: data.startedAt?.toDate() ?? new Date(0),
    endedAt: data.endedAt?.toDate() ?? null,
    distance: data.distance ?? 0,
    movingTime: data.movingTime ?? 0,
    elevationGain: data.elevationGain ?? 0,
    pointCount: data.pointCount ?? 0,
    coordinates,
  };
}

/// Capped because every document read counts against the free Firestore
/// quota, and nobody scrolls back past a couple of hundred walks.
const HISTORY_LIMIT = 200;

async function loadWalks(uid) {
  const snapshot = await getDocs(
    query(
      collection(db, "users", uid, "walks"),
      orderBy("startedAt", "desc"),
      limit(HISTORY_LIMIT),
    ),
  );
  return snapshot.docs.map(toWalk);
}

// --- rendering ----------------------------------------------------------

function renderDetail(walk) {
  const elapsed = walk.endedAt
    ? (walk.endedAt - walk.startedAt) / 1000
    : walk.movingTime;

  el("detail-stats").innerHTML = [
    ["Distance", metres(walk.distance)],
    ["Duration", duration(elapsed)],
    ["Moving", duration(walk.movingTime)],
    ["Pace", pace(walk.distance, walk.movingTime)],
    ["Climb", `${Math.round(walk.elevationGain)} m`],
    ["Fixes", String(walk.pointCount)],
  ]
    .map(
      ([label, value]) =>
        `<div class="tile"><strong>${value}</strong><span>${label}</span></div>`,
    )
    .join("");

  drawRoute(walk);
}

function select(walks, id) {
  const walk = walks.find((w) => w.id === id);
  if (!walk) return;
  for (const node of document.querySelectorAll(".walk-list li")) {
    const selected = node.dataset.id === id;
    node.classList.toggle("selected", selected);
    node.setAttribute("aria-current", selected ? "true" : "false");
  }
  renderDetail(walk);
}

function renderList(walks) {
  const list = el("walk-list");
  list.innerHTML = "";

  for (const walk of walks) {
    const item = document.createElement("li");
    item.dataset.id = walk.id;
    item.tabIndex = 0;
    item.setAttribute("role", "button");
    item.setAttribute("aria-label", `${walkName(walk.startedAt)}, ${metres(walk.distance)}`);
    item.innerHTML =
      `<strong>${walkName(walk.startedAt)}</strong>` +
      `<span>${metres(walk.distance)} · ${duration(walk.movingTime)}</span>`;
    item.addEventListener("click", () => select(walks, walk.id));
    item.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        select(walks, walk.id);
      }
    });
    list.append(item);
  }
}

// --- wiring -------------------------------------------------------------

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

  if (!user) {
    show("loading", false);
    show("history", false);
    show("empty", false);
    show("signed-out", true);
    return;
  }

  el("account-name").textContent = user.displayName ?? user.email ?? "";
  show("signed-out", false);
  show("history", false);
  show("empty", false);
  show("loading", true);

  try {
    const walks = await loadWalks(user.uid);
    show("loading", false);

    if (walks.length === 0) {
      show("empty", true);
      return;
    }

    renderList(walks);
    show("history", true);
    select(walks, walks[0].id);
  } catch (error) {
    fail(error.message);
  }
});
