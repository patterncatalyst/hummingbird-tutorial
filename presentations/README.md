# Presentations

A Red Hat-branded slide deck introducing Project Hummingbird / Red Hat
Hardened Images to an audience of admins.

## The deck

**`hummingbird-overview.pptx`** — 38 slides, 16:9, with full speaker notes on
every slide. Open it in PowerPoint, Keynote, or LibreOffice Impress.

The filename is intentionally **unversioned** — git history is the source of
truth for revisions. The current revision is shown on the cover slide (the
`REV` marker) and recorded in the changelog below.

Structure: a "What is Hummingbird" section, a diagram-led "Working with the
images" tour, a "demo walkthrough" mapping to the eight command-line demos,
and a "Supply chain security" close-out that sets up the generic supply-chain
threat model, overlays the answer, and ends on the runtime attack surface.

## Currency — reviewed against GA (May 12, 2026)

Product claims were checked against Red Hat's GA materials
(redhat.com/en/blog/red-hat-hardened-images, images.redhat.com,
hummingbird-project.io). Highlights: RHHI is the GA product, Project
Hummingbird the upstream engine; free on any Linux/Kubernetes/engine with
optional LTS; 45+ images / 150+ variants; SLSA 3 (Konflux); compliance via
OpenSCAP; default non-root user UID 65532 (the example Containerfiles pin
USER 1001 by choice); Trusted Libraries Tech Preview, Python-only.

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

- **r01.5** — Editorial pass: removed framing that positioned the deck as a
  companion to the tutorial (eyebrows, subtitles, and notes now describe the
  workflow on its own terms), and removed hedging words ("honestly", "be
  candid", "engineering truth", etc.) that implied the surrounding claims
  were otherwise less than straight. No structural or factual changes.
- **r01.4** — Supply-chain close-out reworked into a problem → answer arc:
  added a generic "set the stage" diagram (Figure 18.1), renumbered the
  attacks+mitigations diagram to 18.2 and the runtime-surface diagram to 18.3,
  and removed the third-party attribution from Figure 18.1. 37 → 38 slides.
- **r01.3** — Added the closing Supply chain security section. 33 → 37 slides.
- **r01.2** — Corrected the default non-root user to UID 65532; stable
  unversioned `.pptx` filename.
- **r01.1** — Reconciled to GA (May 12, 2026).
- **r01.0** — Initial deck (not released).

## Status

**Reviewed.** Builds, eyeballed page-by-page, product claims checked against
Red Hat GA materials. Confirm image names/tags/paths against `images.redhat.com`
before an external talk.
