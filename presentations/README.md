# Presentations

A Red Hat-branded slide deck introducing Project Hummingbird / Red Hat
Hardened Images to an audience of admins, built to pair with this tutorial
and its command-line demos.

## The deck

**`hummingbird-overview.pptx`** — 38 slides, 16:9, with full speaker notes on
every slide. Open it in PowerPoint, Keynote, or LibreOffice Impress.

The filename is intentionally **unversioned** — git history is the source of
truth for revisions. The current revision is shown on the cover slide (the
`REV` marker) and recorded in the changelog below.

Structure: a "What is Hummingbird" section, a diagram-led "Working with the
images" tour (one stop per tutorial chapter), a "demo walkthrough" mapping to
the eight command-line demos, and a **"Supply chain security" close-out** that
sets up the generic supply-chain threat model, overlays the Hummingbird
answer, and ends on the runtime attack surface. All of the tutorial's diagrams
are embedded.

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

- **r01.4** — Supply-chain close-out reworked into a problem → answer arc.
  Added a generic "set the stage" diagram (Figure 18.1, the container supply
  chain and its attack vectors), renumbered the existing attacks+mitigations
  diagram to Figure 18.2 and the runtime-surface diagram to Figure 18.3, and
  removed the third-party attribution from Figure 18.1/18.2. 37 → 38 slides.
- **r01.3** — Added the closing Supply chain security section (divider, two
  diagram slides, a division-of-labour table). 33 → 37 slides.
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
