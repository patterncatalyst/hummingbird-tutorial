# Presentations

A Red Hat-branded slide deck introducing Project Hummingbird / Red Hat
Hardened Images to a professional, container-literate audience.

## The deck

**`hummingbird-overview.pptx`** — 43 slides, 16:9, with detailed speaker
notes on every slide. Open it in PowerPoint, Keynote, or LibreOffice Impress.

The speaker notes are written to carry a live talk: they define the
acronyms a technical audience will ask about (SLSA, PIE/RELRO/FORTIFY_SOURCE,
CIS/STIG/OpenSCAP, provenance, Konflux, Trusted Artifact Signer), walk the
debug-sidecar and supply-chain diagrams step by step, and name the
production tooling (Grype, Trivy, Clair, RHACS Scanner V4) rather than only
the demo tool.

## Currency — reviewed against GA (May 12, 2026)

Product claims checked against Red Hat's GA materials (images.redhat.com,
redhat.com, hummingbird-project.io) and developer documentation. RHHI is the
GA product, Project Hummingbird the upstream engine; free on any
Linux/Kubernetes/engine with optional LTS; 45+ images / 150+ variants; built
in Konflux with SLSA 3 signed provenance + SBOM; compliance via OpenSCAP;
default non-root UID 65532 (example Containerfiles pin USER 1001 by choice);
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

The `.pptx` filename is stable; the revision is no longer printed on the
slides. Revisions live in git history and in this changelog; bump the `REV`
constant in `src/deck.js` on each change.

### Changelog

- **r01.7** — Professional-audience pass. Removed the on-slide revision
  marker and remaining hedging language. Expanded speaker notes throughout
  with definitions (SLSA, PIE/RELRO/FORTIFY_SOURCE/annobin, CIS/STIG/
  OpenSCAP, provenance, Konflux, Trusted Artifact Signer, SLSA L3) and
  step-by-step walkthroughs (debug sidecar; per-stage supply-chain attack
  and mitigation; runtime exploits and platform controls). Added real-world
  scanner guidance (Grype/Trivy/Clair/RHACS Scanner V4, VEX) and SBOM
  retrieval detail (registry attestation vs in-image rpmdb; vendor SBOMs).
  New slides: a multi-stage Containerfile example, a CVE-scanning CLI
  example, and a Trusted Libraries value diagram. Rebuilt the compose
  diagram (fixed overlapping labels) and added the SciPy/libstdc++
  "when not to use" gotcha. 40 → 43 slides.
- **r01.6** — Added an agenda slide and a closing thank-you slide.
- **r01.5** — Removed tutorial-companion framing and hedging words.
- **r01.4** — Supply-chain close-out reworked into problem → answer; added
  the generic stage-setter and renumbered the figures.
- **r01.3** — Added the Supply chain security section.
- **r01.2** — UID 65532 fix; stable unversioned filename.
- **r01.1** — Reconciled to GA (May 12, 2026).

## Status

**Reviewed.** Builds, eyeballed page-by-page, product claims checked against
Red Hat GA materials. Confirm image names/tags/paths against
`images.redhat.com` before an external talk.
