# Presentations

A Red Hat-branded slide deck introducing Project Hummingbird / Red Hat
Hardened Images to an audience of admins, built to pair with this tutorial
and its command-line demos.

## The deck

**`hummingbird-overview.pptx`** — 37 slides, 16:9, with full speaker notes on
every slide. Open it in PowerPoint, Keynote, or LibreOffice Impress.

The filename is intentionally **unversioned** — git history is the source of
truth for revisions. The current revision is shown on the cover slide (the
`REV` marker) and recorded in the changelog below.

Structure: a "What is Hummingbird" section, a diagram-led "Working with the
images" tour (one stop per tutorial chapter), a "demo walkthrough" mapping to
the eight command-line demos, and a **"Supply chain security" close-out** that
places the hardened image on the standard container supply-chain threat model.
All 13 of the tutorial's diagrams are embedded.

## Currency — reviewed against GA (May 12, 2026)

Product claims were checked against Red Hat's GA materials
(redhat.com/en/blog/red-hat-hardened-images, images.redhat.com,
hummingbird-project.io). Highlights: RHHI is the GA product, Project
Hummingbird the upstream engine; free on any Linux/Kubernetes/engine with
optional LTS; 45+ images / 150+ variants; SLSA 3 (Konflux); compliance via
OpenSCAP; default non-root user UID 65532 (examples pin USER 1001 by choice);
Trusted Libraries Tech Preview, Python-only.

## Rebuilding it

```bash
cd presentations/src
./convert-diagrams.sh   # optional: regenerate PNGs from ../../assets/diagrams/*.svg
./build.sh              # writes ../hummingbird-overview.pptx (needs Node + pptxgenjs)
```

`src/` holds `deck.js` (one block per slide), the bundled `deck-helpers.js`,
brand `assets/`, and rendered diagram `png/`.

## Versioning

The `.pptx` filename is stable; revisions live in git history. On each change,
bump the `REV` constant in `src/deck.js` (it prints on the cover) and add a
changelog entry here.

### Changelog

- **r01.3** — Added a closing **Supply chain security** section (4 slides:
  divider, the attack-vectors pipeline, the layered runtime surface, and a
  "division of labour" table), reframing Liz Rice's *Container Security* (2e)
  ch. 7 threat model for Podman/OpenShift/RHEL and showing where a near-zero-
  CVE distroless base closes vectors by construction — and where it doesn't.
  Two new diagrams added (`18-supply-chain-security-*`). 33 → 37 slides.
- **r01.2** — Corrected the default non-root user to UID 65532 (was 1001);
  made the multi-stage note UID-agnostic; switched to a stable unversioned
  `.pptx` filename.
- **r01.1** — Reconciled to GA (May 12, 2026): launch/status, RHHI-vs-
  Hummingbird framing, catalog components (Valkey/HAProxy), cost/support,
  SLSA 3 wording, OpenSCAP. Fixed a builder bug that dropped detail lines.
- **r01.0** — Initial deck (not released).

## Status

**Reviewed.** Builds, eyeballed page-by-page, product claims checked against
Red Hat GA materials. Confirm image names/tags/paths against `images.redhat.com`
before an external talk.
