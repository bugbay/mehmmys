# Mehmmy — Ride Rewards PWA

A friends-only ride loyalty app. Give a friend a **Mehmmy** every time they drive you, track points + real driving miles, climb the leaderboard, and redeem rewards.

This folder is a **complete, installable Progressive Web App** — no build step, no framework, no server code. Just static files.

## Files
- `index.html` — the whole app (vanilla HTML/CSS/JS)
- `manifest.webmanifest` — app name, icons, theme, standalone display
- `service-worker.js` — offline caching of the app shell
- `firebase-config.js` — **paste your Firebase keys here** (optional; see below)
- `firebase-sync.js` — live shared-leaderboard sync (loads only when configured)
- `icons/` — install icons (standard + maskable + Apple touch)

## Shared leaderboard (Firebase)
The app works on each phone by itself out of the box (data saved on-device). To make **one live leaderboard shared across everyone's phones**, follow **`FIREBASE_SETUP.md`** — paste your Firebase web config into `firebase-config.js`, give every friend the same `GROUP_ID`, and redeploy. The **Me** screen shows a **Live / Local** badge so you know the state. If the cloud is ever unreachable it falls back to on-device mode automatically.

## Installing
- **Android / Chrome / Edge** — an **Install** button appears on the Me screen (and the browser's own install prompt).
- **iPhone / Safari** — a banner explains the steps: tap **Share** → **Add to Home Screen** (iOS doesn't allow a one-tap install).

## Run locally
A service worker needs to be served over `http://` (not opened as a `file://`). From this folder:

```bash
# Python
python3 -m http.server 8080
# or Node
npx serve .
```

Then open `http://localhost:8080`. On a phone, your browser's menu will offer **"Add to Home Screen" / "Install"**.

## Deploy (any static host)
Upload the contents of this `pwa/` folder to any HTTPS static host — the app is fully self-contained:

- **Netlify / Vercel** — drag-and-drop the folder, or point it at the repo with this as the publish directory.
- **GitHub Pages** — push the folder, enable Pages, done.
- **Cloudflare Pages / Firebase Hosting / S3+CloudFront** — upload as-is.

HTTPS is required for service workers and install prompts (all the hosts above provide it automatically).

## Maps / mileage
Distances use **OpenStreetMap** services:
- **OSRM** (`router.project-osrm.org`) for real driving distance.
- **Nominatim** (`nominatim.openstreetmap.org`) to geocode searched addresses.

These are the free **public demo servers** — fine for personal/prototype use but rate-limited and **not for production traffic**. For a real launch, self-host OSRM/Nominatim or use a paid provider (e.g. OpenRouteService, Mapbox) and swap the two `fetch` URLs in `index.html`. If a request fails, the app falls back to a straight-line estimate so logging never breaks.

## Data
All data (crew, places, rides, points) is stored **locally on the device** via `localStorage` — nothing is sent anywhere. Clearing site data resets the app. There is no multi-user sync yet; for a shared leaderboard across friends you'd add a backend (e.g. Supabase/Firebase).
