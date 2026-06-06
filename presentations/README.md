# Presentations

A Red Hat-branded slide deck introducing Project Hummingbird / Red Hat
Hardened Images to an audience of admins, built to pair with this tutorial
and its command-line demos.

## The deck

**`hummingbird-overview-r01.2.pptx`** — 33 slides, 16:9, with full speaker
notes on every slide. Open it in PowerPoint, Keynote, or LibreOffice
Impress.

Structure: a large "What is Hummingbird" section, a diagram-led "Working
with the images" tour (one stop per tutorial chapter), and a closing
"demo walkthrough" mapping to the eight command-line demos. All 11 of the
tutorial's diagrams are embedded.

## Currency — reviewed against GA (May 12, 2026)

Product claims were checked against Red Hat's GA materials
(redhat.com/en/blog/red-hat-hardened-images, images.redhat.com,
hummingbird-project.io). Highlights reflected in the deck:

- **Red Hat Hardened Images (RHHI)** is the GA product; **Project
  Hummingbird** is the upstream innovation engine. Catalog at
  `images.redhat.com`; community mirror at `quay.io/hummingbird` (unsigned);
  signed images at `registry.access.redhat.com/hi/`.
- Free on any Linux/Kubernetes/engine; optional LTS via subscription.
- 45+ images, 150+ variants (AMD64/Arm64). GA components include Python,
  Node.js, Go, Java, .NET, PostgreSQL, Valkey, Nginx, HAProxy.
- SLSA 3 pipeline (Konflux); compliance verifiable via OpenSCAP.
- **Default non-root user is UID 65532** (where technically possible). Note
  the tutorial's *example* Containerfiles deliberately pin `USER 1001`.
- Trusted Libraries: Tech Preview, Python-only, part of Red Hat Advanced
  Developer Suite.

Re-check exact image names/tags/pull paths against `images.redhat.com`
before an external talk.

## Rebuilding it

```bash
cd presentations/src
./convert-diagrams.sh   # optional: regenerate PNGs from ../../assets/diagrams/*.svg
./build.sh              # writes ../hummingbird-overview-r01.2.pptx (needs Node + pptxgenjs)
```

`src/` holds `deck.js` (one block per slide), the bundled `deck-helpers.js`,
brand `assets/`, and rendered diagram `png/`.

## Versioning

Filename carries the revision. Bump the major for a new section, `.x` for a
fix; update both the `OUT` constant and the on-cover `REV` in `src/deck.js`.

### Changelog

- **r01.2** — Corrected the default non-root user to **UID 65532** (was
  1001) on the "what's in an image" and four-layers slides, and made the
  multi-stage speaker note UID-agnostic. (The tutorial's example
  Containerfiles still pin `USER 1001` by choice — that's unchanged.)
- **r01.1** — Reconciled to GA (May 12, 2026): launch/status, RHHI-vs-
  Hummingbird framing, catalog components (Valkey/HAProxy), cost/support,
  SLSA 3 wording, OpenSCAP. Fixed a builder bug that dropped detail lines
  under headline bullets.
- **r01.0** — Initial deck (not released).

## Status

**Reviewed.** Builds, eyeballed page-by-page, product claims checked against
Red Hat GA materials. Confirm image names/tags/paths against
`images.redhat.com` before an external talk.
