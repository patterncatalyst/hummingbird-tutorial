# Presentations

A Red Hat-branded slide deck introducing Project Hummingbird / Red Hat
Hardened Images to an audience of admins, built to pair with this tutorial
and its command-line demos.

## The deck

**`hummingbird-overview-r01.1.pptx`** — 33 slides, 16:9, with full speaker
notes on every slide. Open it in PowerPoint, Keynote, or LibreOffice
Impress.

Structure:

- **What is Hummingbird** (the bulk) — the catalog, "rebuild don't patch",
  what "near-zero CVE" honestly means, where it sits next to UBI, what's in
  an image and what isn't, the image variants, the four-layer hardening
  stack, the three named concepts, the UBI comparison, and why Podman.
  Includes both §2 figures (ecosystem, hardening pyramid).
- **Working with the images** — a diagram-led tour, one stop per tutorial
  section: prerequisites, podman basics, the debug sidecar, the four
  debugging layers, multi-stage builds, SBOMs & signing, CVE scanning,
  Podman Compose, zstd:chunked, chunkah, trusted libraries, and gotchas.
- **The demo walkthrough** — the eight command-line demos from `demos/`,
  with how-they-run, two summary tables, and the commands to drive them.

Every figure in the deck is one of the tutorial's own diagrams
(`assets/diagrams/*.svg`), rendered to PNG — all 11 are embedded.

## Currency — reviewed against GA (May 12, 2026)

The product went generally available at Red Hat Summit on **May 12, 2026**.
The deck's product claims were reviewed against Red Hat's GA materials
(redhat.com/en/blog/red-hat-hardened-images, images.redhat.com, the GA press
release, and hummingbird-project.io). Key facts as reflected in r01.1:

- **Red Hat Hardened Images (RHHI)** is the GA product; **Project
  Hummingbird** was the early-access program and continues as the upstream
  innovation engine (community images at `quay.io/hummingbird`; GA catalog
  at `images.redhat.com`).
- **Free to use on any Linux distribution, Kubernetes, or container
  engine** (vendor-neutral); optional **LTS images planned via
  subscription**.
- Catalog scale: **45+ images, 150+ variants**, including AMD64/Arm64 builds.
- GA-named components: **Python, Node.js, Go, Java, .NET, PostgreSQL,
  Valkey, Nginx, HAProxy**, and more.
- Built on Red Hat's **SLSA 3 pipeline (Konflux)**; compliance verifiable
  via **OpenSCAP**.
- **Red Hat Trusted Libraries** remains **Tech Preview, Python-only** (npm
  and Java planned), SLSA 3, now part of Red Hat Advanced Developer Suite.

Re-check the exact image names, tags, and registry/pull paths against
`images.redhat.com` before presenting externally — those evolve.

## Rebuilding it

The deck is generated from JavaScript (pptxgenjs), in the house style of
the `lgtm-presentation` skill. Sources are under `src/`.

```bash
cd presentations/src

# (optional) regenerate the diagram PNGs from the tutorial's SVGs
#   needs: soffice (LibreOffice), pdftoppm (poppler), convert (ImageMagick)
./convert-diagrams.sh

# build the .pptx (writes ../hummingbird-overview-r01.1.pptx)
#   needs: Node.js + pptxgenjs  (npm install -g pptxgenjs)
./build.sh
```

`src/` contains `deck.js` (the builder — one block per slide), the bundled
`deck-helpers.js`, the brand `assets/`, and the rendered diagram `png/`.

## Versioning

Filename carries the revision: `hummingbird-overview-rNN.x.pptx`. Bump the
major for a new section, `.x` for a fix; update both the `OUT` constant and
the on-cover `REV` marker in `src/deck.js`.

### Changelog

- **r01.1** — Reconciled to GA (May 12, 2026): corrected launch/status and
  the RHHI-vs-Hummingbird relationship; updated catalog components
  (Valkey/HAProxy in, MariaDB/Caddy out) and scale (45+/150+); changed the
  cost/support framing to free-on-any-platform + planned LTS; aligned SLSA
  wording to "SLSA 3 (Konflux)" and compliance to OpenSCAP; noted Trusted
  Libraries is now part of Advanced Developer Suite. Also fixed a builder
  bug where the detail line under headline bullets (hardening layers, the
  three concepts, the overview) was being dropped.
- **r01.0** — Initial deck (not released).

## Status

**Reviewed.** The deck builds, has been eyeballed page-by-page, and its
product claims were checked against Red Hat's GA materials. Image names,
tags, and pull paths still warrant a quick re-check against
`images.redhat.com` before an external talk.
