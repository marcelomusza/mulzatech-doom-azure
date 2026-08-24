# ADR 0002: Use JS-DOS instead of a VNC/streaming-based DOS runtime

## Status

Accepted

## Context

The application needs to run the original DOOM (a 1993 DOS binary) inside a
browser, served from a container behind an Azure Container Apps ingress.
There are two broadly different ways to get a DOS-era binary running in a
browser:

- **VNC/remote-display streaming** — run a real (or emulated) DOS
  environment inside the container (e.g. via DOSBox under Xvfb), expose it
  through a VNC server, and stream the display to the browser via a web VNC
  client such as noVNC or a Kasm-style workspace image.
- **In-browser WebAssembly DOS emulation** — compile a DOS emulator
  (DOSBox) to WebAssembly and run it directly in the user's browser. The
  container's only job is to serve static files (the WASM emulator runtime,
  supporting JS, and the game's WAD data) over plain HTTP. **JS-DOS** is the
  most established project doing this.

## Decision

Use **JS-DOS** (WebAssembly DOS emulation running client-side) rather than a
VNC/streaming-based approach.

## Options considered

| Option | Why not chosen |
|---|---|
| VNC / noVNC / Kasm-style container | Requires a persistent stateful connection (VNC over WebSocket) between browser and container, rather than plain request/response HTTP. Needs a full Linux desktop or Xvfb + window manager + VNC server running inside the container, and typically needs elevated shared-memory container flags (e.g. `--shm-size`) to run smoothly. Resulting images tend to run 900MB+ once a desktop environment, DOSBox, and VNC tooling are layered together. Every player also occupies a live server-side session with its own emulator process, which does not scale statelessly the way a static file server does. |
| JS-DOS (chosen) | See rationale below. |

## Rationale

- **Pure HTTP.** JS-DOS ships the emulator as WebAssembly + JS + static
  assets. The browser downloads them once and runs the entire DOS
  environment locally — no persistent server-side connection, no
  WebSocket/VNC protocol to keep alive, no server-side session state per
  player.
- **Deployment-friendly on Container Apps.** Azure Container Apps' ingress
  is built around standard HTTP(S) traffic. A stateless static file server
  is the path of least resistance there; a stateful VNC/WebSocket backend
  would need session affinity and would fight the platform's scale-to-zero,
  stateless-by-default model.
- **Image size.** A static file server serving a few tens of MB of WASM/JS
  assets is dramatically smaller than a container image bundling a
  Linux desktop environment, DOSBox, and a VNC server (900MB+ is typical
  for that class of image).
- **No special container runtime flags.** VNC/X11-based approaches
  frequently need `--shm-size` increases or other runtime tuning to avoid
  crashes; a static file server needs none of that, which keeps the
  Container Apps configuration simpler.
- **Scales the way the rest of the app does.** Since all emulation happens
  in the player's own browser, serving more concurrent players is just
  serving more static file requests — no additional server-side CPU/RAM
  per session the way a server-rendered VNC desktop would need.

## Consequences

- The container is, and stays, a plain static file server. No DOS emulator,
  X server, or VNC server ever runs server-side.
- All emulation cost (CPU, memory) is shifted to the player's browser. This
  is a good trade for a lightweight DOS-era game; it would not necessarily
  hold for a heavier emulation target.
- The Dockerfile is built from scratch (static file server + js-dos runtime
  + the shareware WAD) rather than pulling an existing finished image, so
  every layer is understood and owned as part of the learning goals of this
  project.
- Running js-dos's WebAssembly backend correctly requires the server to
  send `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp` response headers, since the
  emulator depends on `SharedArrayBuffer`, which browsers only expose on
  cross-origin-isolated pages. This is a concrete requirement the static
  file server (and later, the Dockerfile's web server config) must satisfy
  — discovered directly while getting Phase 0 working.
