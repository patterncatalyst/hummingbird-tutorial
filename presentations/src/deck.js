// deck.js — Project Hummingbird (Red Hat Hardened Images) overview deck.
// Built with the lgtm-presentation skill. Diagrams are the project's own
// figures, converted SVG -> PNG into ./png.
//
// Build:  export NODE_PATH=$(npm root -g) && node deck.js

"use strict";

const H = require("./deck-helpers.js");
const {
  COLOR, FONT, W, ASSETS,
  newDeck, addFooter, addContentTitle, addBullets, addTwoColBullets,
  addStatusTable, addCaption, addCodeSlide, addDiagramSlide, addSectionDivider, addNotes,
} = H;

const OUT = "../hummingbird-overview.pptx";
const REV = "r01.7";

const pres = newDeck();
let pageNum = 0;

function S() { const s = pres.addSlide(); pageNum += 1; addFooter(s, pageNum); return s; }
function divider(code, title, subtitle, notes) {
  const s = pres.addSlide(); pageNum += 1; addSectionDivider(s, code, title, subtitle); addNotes(s, notes);
}

// The bundled addBullets reads {text, sub} only to choose a bullet glyph — it
// never renders the sub string. This expands each {text, sub} into a bold
// headline bullet followed by a grey, indented detail line, then hands the
// flat list to addBullets (helper left untouched).
function bsub(items) {
  const out = [];
  for (const ln of items) {
    if (typeof ln === "string" || !ln.sub) { out.push(ln); continue; }
    out.push({ text: ln.text, options: { bullet: { code: "25CF" }, bold: true, paraSpaceAfter: 2, breakLine: true, ...(ln.options || {}) } });
    out.push({ text: ln.sub, options: { bullet: false, color: COLOR.caption, fontSize: 13, indentLevel: 1, paraSpaceAfter: 12, breakLine: true } });
  }
  return out;
}

/* ════════════════════════════════ COVER ════════════════════════════════ */
{
  const s = pres.addSlide();
  pageNum += 1;
  s.background = { color: COLOR.white };
  try { s.addImage({ path: `${ASSETS}/cover-panel.png`, x: 0, y: 0, w: W, h: 7.5 }); } catch (e) {}
  s.addText("RED HAT HARDENED IMAGES · RHHI", { x: 6.00, y: 1.98, w: 6.90, h: 0.34,
    fontFace: FONT.title, fontSize: 14, bold: true, color: COLOR.red, charSpacing: 6, align: "left", valign: "middle" });
  s.addText([{ text: "Project", options: { breakLine: true } }, { text: "Hummingbird" }], {
    x: 5.95, y: 2.42, w: 6.95, h: 2.00, fontFace: FONT.title, fontSize: 54, bold: true, color: COLOR.ink, align: "left", valign: "top" });
  s.addText("Minimal, hardened, near-zero-CVE container images — generally available since Red Hat Summit 2026 — and how to work with them at the command line with Podman.",
    { x: 6.00, y: 4.45, w: 6.80, h: 1.25, fontFace: FONT.body, fontSize: 17, italic: true, color: COLOR.caption, align: "left", valign: "top" });
  try { s.addImage({ path: `${ASSETS}/logo-candidate-2.png`, x: 11.10, y: 6.80, w: 1.55, h: 0.37 }); } catch (e) {}
  addNotes(s, "This deck is a walkthrough of Project Hummingbird — Red Hat's catalog of hardened, near-zero-CVE container images, officially Red Hat Hardened Images (RHHI). The bulk of it answers 'what is it and why does it exist'; the back half tours how you actually work with the images, and it closes with a set of live command-line demos. The audience is admins and platform engineers. Everything runs locally on Podman on a laptop — no cluster, no managed cloud required.");
}

/* ════════════════════════════════ AGENDA ═══════════════════════════════ */
{
  const s = S();
  addContentTitle(s, "AGENDA", "What we'll cover");
  addBullets(s, bsub([
    { text: "01 · What is Project Hummingbird?", sub: "The catalog, the one idea that drives it — rebuild instead of patch — what \u201cnear-zero CVE\u201d really means, where it sits next to UBI, and the trust chain." },
    { text: "02 · Working with the images", sub: "A diagram-led tour: pulling and inspecting, the debug-sidecar pattern, multi-stage builds, SBOMs and signing, CVE scanning, compose, efficient layers, trusted libraries, and the distroless gotchas." },
    { text: "03 · The demo walkthrough", sub: "Eight live command-line demos, start to finish, entirely on Podman." },
    { text: "04 · Supply chain security", sub: "The supply-chain threat model, the Hummingbird answer at each stage, and the layered runtime attack surface." },
  ]), { fontSize: 15 });
  addNotes(s, "Quick map of the next 40-odd slides. The first part is conceptual — what the catalog is and why it exists — because once that lands, the commands read as obvious. The second part is the hands-on tour, one stop per topic led by its diagram. Then we go to the terminal for eight live demos. We close on supply chain security: the generic threat model, how a hardened base answers it, and the runtime attack surface. The whole thing runs locally on Podman — no cluster required.");
}

/* ═══════════════════ SECTION 1 — WHAT IS HUMMINGBIRD ════════════════════ */
divider("01", "What is Project Hummingbird?", "The conceptual grounding before any commands.",
  "This is the part to get right before touching a terminal. We'll cover what the catalog is, the one idea that drives the whole design — rebuild instead of patch — what 'near-zero CVE' really means, where Hummingbird sits next to UBI, what's deliberately left out of an image, the image variants, what 'hardened' means concretely, and the three named concepts behind the trust chain. Once this lands, the commands later read as obvious rather than magic.");

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · OVERVIEW", "A catalog of minimal, hardened images");
  addBullets(s, bsub([
    { text: "Red Hat's catalog of minimal, hardened container images, built to mitigate as many known vulnerabilities as possible at release time.", sub: "Red Hat Hardened Images (RHHI) is the product; Project Hummingbird was the early-access program and continues as the upstream innovation engine that produces it." },
    { text: "Generally available since May 12, 2026 (Red Hat Summit), after an early-access run with hundreds of users; built on Red Hat's SLSA 3 (Konflux) pipeline.", },
    { text: "Free to use on any Linux distribution, Kubernetes, or container engine \u2014 vendor-neutral, no subscription. Optional long-term-support (LTS) images are planned via subscription.", },
    { text: "Over 45 images and 150+ variants: languages/runtimes (Python, Node.js, Go, Java, .NET), databases (PostgreSQL, Valkey), web servers/proxies (Nginx, HAProxy), and utilities.", },
  ]), { fontSize: 15 });
  addNotes(s, "Hummingbird is a catalog, not a single image, and the framing matters now that it's GA: Red Hat Hardened Images is the generally available product as of May 12, 2026 (Red Hat Summit, Atlanta); Project Hummingbird was the early-access program and continues as the upstream innovation engine that feeds the catalog (community images still live at quay.io/hummingbird; the GA catalog is at images.redhat.com). It rides the existing Red Hat trust chain — SLSA 3 builds via Konflux. The big GA change to internalize: it's free to use anywhere — any Linux distro, any Kubernetes, any container engine, no subscription — with optional LTS images planned later via subscription. The catalog is 45+ images and 150+ variants, deliberately scoped to the components customers ask for most.");
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · THE CORE IDEA", "Rebuild, don't patch");
  addBullets(s, [
    "Traditional base images carry hundreds of packages and a long history of patches; a new CVE means backport-and-rebuild, often weeks behind the upstream fix.",
    "Hummingbird inverts the loop: it is its own distroless distribution, and when an upstream fix lands the image is rebuilt clean from new components rather than patched in place.",
    { text: "Combined with a small dependency graph, that means:", options: { bullet: false, bold: true } },
    "Rebuilds are fast — fixes typically ship within hours of an upstream fix landing.",
    "The rebuilt image carries no historical CVE legacy.",
    "The SBOM is small enough that you can actually read it.",
  ], { fontSize: 16 });
  addNotes(s, "This is the single most important slide. Everything else follows from it. The old model is additive: you start big and keep patching. Hummingbird is subtractive and regenerative: start minimal, and when something upstream is fixed, throw the image away and rebuild it clean. Because the dependency graph is tiny, rebuilds are cheap, fixes land fast, and there's no accumulated patch history dragging behind. The small graph also makes the SBOM human-readable — which becomes the foundation for the signing and scanning stories later.");
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · THE CLAIM", "What \u201cnear-zero CVE\u201d really means");
  addBullets(s, [
    "Around 160 new CVEs are disclosed daily — an image that scans clean at 9 a.m. can have a CVE by 5 p.m. A literal, permanent zero is not achievable, and the accurate phrase is \u201cnear-zero\u201d.",
    { text: "What Hummingbird actually holds:", options: { bullet: false, bold: true } },
    { text: "Zero CVE at the moment of publication — every image is rebuilt and re-scanned.", },
    { text: "Continuous rebuild on upstream fixes — staying close to the moving zero line.", },
    { text: "Functionality testing as part of the rebuild — fixes don't silently break the image.", },
  ], { fontSize: 16 });
  addCaption(s, "We scan a Hummingbird image ourselves later — \u201cnear-zero\u201d is a measurement, not a slogan.");
  addNotes(s, "Worth stating plainly — it earns trust. 'Zero CVE' is the marketing; 'near-zero CVE' is the engineering reality, and the difference is just how vulnerability disclosure works. The zero line moves every day. What you can actually guarantee is: clean at publication, continuous rebuilds that chase the line, and functional testing so a security rebuild doesn't break your workload. In the CVE-scanning demo the audience watches Grype put real numbers behind this against a hardened image versus a general-purpose one.");
}

{
  const s = S();
  addDiagramSlide(s, "WHAT IS HUMMINGBIRD · ECOSYSTEM",
    "Where Hummingbird fits in the Red Hat container ecosystem",
    "02-introduction-ecosystem",
    "Figure 2.1 — Hummingbird and UBI are sibling image bases drawing from one shared component pipeline.");
  addNotes(s, "The key correction this diagram makes: Hummingbird and UBI are siblings, not stacked layers. Fedora is the fast-moving upstream; the Red Hat package pipeline stabilizes, signs, and publishes components; then two distinct image bases assemble those same components into different shapes — UBI as the full enterprise base, Hummingbird as the distroless minimal base. OpenShift and Kubernetes run images of either kind. The first two rows are the shared trust chain; the next two are the bases themselves.");
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · SIBLINGS, NOT LAYERS", "UBI and Hummingbird are complementary");
  addTwoColBullets(s,
    [
      { text: "UBI — reach for breadth", options: { bullet: false, bold: true } },
      "Familiar RPM-based environment.",
      "Broad package availability; dnf at runtime.",
      "Builder stages and RPM-managed middleware.",
      { text: "Predictable 10-year life cycle.", muted: true },
    ],
    [
      { text: "Hummingbird — reach for minimalism", options: { bullet: false, bold: true } },
      "Smallest, hardest-to-attack runtime.",
      "Final stage of a multi-stage build.",
      "Compiled binary, a JAR, or a Node bundle.",
      { text: "Continuous, rolling rebuilds.", muted: true },
    ]);
  addNotes(s, "Hummingbird does not replace UBI; most real platforms use both. The mental model: UBI when you need a familiar RHEL userspace and the ability to install packages — typically builder stages and middleware. Hummingbird when you want the smallest possible attack surface — typically the deploy stage that ships a compiled artifact. The Quarkus example does both: it builds on UBI (which ships Maven) and deploys on a hardened JRE. Mixing per-stage is the common, correct shape.");
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · CONTENTS", "What's in an image — and what isn't");
  addTwoColBullets(s,
    [
      { text: "Typically contains", options: { bullet: false, bold: true } },
      "The application runtime (JVM, Node, Python, or a shared-library set).",
      "Only the OS libraries that runtime depends on.",
      "A non-root default user (UID 65532 where technically possible).",
      "OCI manifest with SBOM + provenance attestations.",
    ],
    [
      { text: "Typically does NOT contain", options: { bullet: false, bold: true } },
      "A shell — podman exec \u2026 /bin/sh fails in most cases.",
      "A package manager (dnf, microdnf, apt, apk).",
      "Diagnostic tools (curl, ps, top, netstat).",
      "A compiler or build toolchain.",
    ]);
  addCaption(s, "The omissions are the design: a much smaller set of things to attack, and to patch.");
  addNotes(s, "The deliberate absences matter as much as the inclusions. What's there: the runtime, its required libraries, a non-root user, and rich OCI metadata. What's gone: shell, package manager, diagnostic tools, compiler. The payoff is twofold — far less for an attacker to use post-compromise, and far less to track and patch. The cost is that debugging changes shape: instead of exec-ing in, you attach a debug sidecar that shares the container's namespaces. That pattern gets its own section.");
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · VARIANTS", "Image variants: default, builder, FIPS");
  addStatusTable(s, [
    { code: "Default", name: ":<version>", purpose: "Distroless baseline — balances distroless principles with upstream compatibility; the production runtime." },
    { code: "Builder", name: ":<version>-builder", purpose: "Retains the hardening and adds a package manager + shell to customize builds." },
    { code: "FIPS", name: ":<version>-fips[-builder]", purpose: "FIPS-validated cryptography for regulated environments." },
  ], { colW: [1.80, 3.40, 6.89], rowH: 0.74 });
  addCaption(s, "Also AMD64 and Arm64 architecture builds (45+ images, 150+ variants). Most defaults have no shell \u2014 Golang, Core Runtime, and full OpenJDK keep one.");
  addNotes(s, "Every image ships in variants identified by tag suffix, plus per-architecture builds (AMD64 and Arm64) — which is how 45+ images become 150+ variants. Default aims to balance distroless principles with compatibility with existing upstream images; it's the production runtime. Builder retains the hardening but adds a package manager and shell so you can customize builds. FIPS adds validated cryptography for regulated environments. One nuance worth carrying over: 'no shell' is the safe assumption, not a universal guarantee — a few default images (Golang, Core Runtime, the full OpenJDK) include a shell because their ecosystems expect it. If your build pattern relies on shell-free runtime, pin the specific variant rather than assuming. Confirm exact tags against the catalog at images.redhat.com.");
}

{
  const s = S();
  addDiagramSlide(s, "WHAT IS HUMMINGBIRD · HARDENING",
    "What \u201chardened\u201d means concretely",
    "02-introduction-hardening-stack",
    "Figure 2.2 — Four hardening layers, applied to every image in the catalog by default.");
  addNotes(s, `'Hardened' isn't a vibe — it's four concrete layers, applied to every image by default and enforced as a release gate. None of the layers is individually novel; the value is doing all four, everywhere, on every rebuild. Bottom to top: Source (provenance + CVE tracking), Packages (hardened compiler flags), Images (distroless, non-root, reproducible), Benchmarks (compliance scanning). The next slide defines each term — a technical audience will ask what they mean.`);
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · HARDENING", "The four layers, bottom to top");
  addBullets(s, bsub([
    { text: "Source — ever-fresh remediations", sub: "SLSA 3 provenance via Red Hat's Konflux pipeline; continuous upstream CVE tracking and automated rebuilds. A signed attestation, not a promise." },
    { text: "Packages — hardened compiler options", sub: "PIE, RELRO, stack protectors, FORTIFY_SOURCE=3; verified in the ELF with annobin/annocheck. Weak deps off (install_weak_deps=False)." },
    { text: "Images — distroless, non-root, reproducible", sub: "Minimal userspace, UID 65532, hermetic builds, signed manifests, attached SBOMs, reproducible across rebuilds." },
    { text: "Benchmarks & scanning — verifiable compliance", sub: "Compliance-related configuration verifiable via OpenSCAP (e.g. CIS, STIG profiles), as part of the release gate. Fail the scan, don't ship." },
  ]), { fontSize: 14 });
  addNotes(s, `This slide is dense and a technical audience will ask what the acronyms are — define them as you go. Bottom to top:

• Source — SLSA 3 provenance, built in Konflux. SLSA (Supply-chain Levels for Software Artifacts) is an OpenSSF framework grading build integrity from 1 to 3; Level 3 means a hardened, isolated build service emits signed, unforgeable provenance. Konflux is Red Hat's Tekton-based build pipeline.
• Packages — RHEL hardening compiler flags, and crucially verified present in the binary:
   – PIE (Position-Independent Executable): lets ASLR randomize where the binary loads, so exploits can't rely on fixed addresses.
   – RELRO (RELocation Read-Only): makes the GOT read-only after startup, blocking GOT-overwrite attacks.
   – stack protectors (-fstack-protector-strong): canaries that catch stack buffer overflows.
   – FORTIFY_SOURCE=3: compile- and run-time bounds checks on common libc calls.
   – annobin/annocheck: annobin records the flags into the ELF; annocheck audits the binary to prove the hardening was actually applied — verification, not a claim.
   – install_weak_deps=False: skip optional 'recommended' packages so nothing sneaks in.
• Images — distroless userspace, non-root (UID 65532 where possible), hermetic reproducible builds, signed manifests, attached SBOMs.
• Benchmarks — compliance config verifiable via OpenSCAP (the open-source scanner for the SCAP standard) against profiles like CIS (Center for Internet Security benchmarks) and STIG (DISA's Security Technical Implementation Guides, used across US government/DoD). Fail the scan, don't ship.

The compounding effect of all four, enforced at release, is what makes 'near-zero CVE' defensible.`);
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · CONCEPTS", "Three concepts behind the trust chain");
  addBullets(s, bsub([
    { text: "Distroless", sub: "The runtime and only what it depends on — no shell, package manager, tools, or compiler. Not the same as \u201csmall\u201d; it's a deliberate attack-surface reduction. It changes how you debug." },
    { text: "Hermetic builds", sub: "No network during the build; only declared, signed inputs. No curl | sh, no \u201clatest\u201d pulls. This is what makes an SBOM describe what's provably in the image, not what claims to be." },
    { text: "Konflux", sub: "The open-source secure supply-chain platform that builds the images — runs the hermetic builds, makes the SBOMs and attestations, signs the artifacts. Invisible to consumers; available for your own builds." },
  ]), { fontSize: 15 });
  addNotes(s, "Three terms worth naming so the audience can go read more. Distroless is the philosophy — runtime plus dependencies, nothing else — and the main reason 'near-zero CVE' is achievable; it's also why debugging changes shape. Hermetic builds are what make SBOMs trustworthy: if the build couldn't reach the network and every input was declared and signed, the SBOM describes what's provably present. Konflux is the machinery that does all of this; consumers never touch it — you just see a signed OCI image with SBOM and attestations — but the same platform is available if you want these properties for your own application images.");
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · UBI COMPARISON", "How Hummingbird compares with UBI");
  addStatusTable(s, [
    { code: "Primary focus", name: "Flexible RHEL userspace", purpose: "Purpose-built minimal attack surface" },
    { code: "Use case", name: "Needs RHEL breadth / life cycle", purpose: "Reduce CVE-management toil" },
    { code: "Update cadence", name: "Standard RHEL errata", purpose: "Continuous and rolling" },
    { code: "Image size", name: "Standard RPM install", purpose: "Distroless, minimal base" },
    { code: "Life cycle", name: "Predictable 10-year", purpose: "Tracks upstream releases" },
    { code: "Support / cost", name: "Full on RHEL/OCP · free", purpose: "Free to use anywhere · LTS planned (subscription)" },
  ], { colW: [2.70, 4.30, 5.09], rowH: 0.62 });
  addNotes(s, "Most platforms end up with both, so compare them on the merits. UBI is the flexible, broad, predictable RHEL base with a 10-year life cycle. Hummingbird is the minimal, rolling, purpose-built hardened base. Both are free; the GA difference to state correctly is that Hardened Images are free to use on any Linux distro, Kubernetes, or container engine — vendor-neutral — with optional LTS images planned via subscription, rather than support being tied to a RHEL/OpenShift subscription. The decision rule repeats: UBI when you need RHEL breadth or dnf at runtime; Hummingbird when you want the smallest, hardest-to-attack runtime — usually the deploy stage. The gotchas section gives concrete failure modes for when the minimal runtime is the wrong tool.");
}

{
  const s = S();
  addContentTitle(s, "WHAT IS HUMMINGBIRD · TOOLING", "Why this works with Podman");
  addBullets(s, [
    "Podman, Buildah, and Skopeo are built around the same OCI specs as the images — no daemon, no privileged process, clean rootless story.",
    "Podman Compose adds multi-container local development; Podman Desktop adds a GUI for size comparison, manifest inspection, and scan results.",
    "The full toolchain runs on a laptop — no cluster to provision — and the same commands work unchanged on Fedora and macOS.",
  ], { fontSize: 16 });
  addNotes(s, "The tooling choice is philosophical, not incidental. Podman, Buildah, and Skopeo speak the same OCI specifications the images are built against, and their daemonless, rootless design matches the 'ship the smallest possible runtime' ethos. Compose covers local multi-service development; Desktop is there for the moments a GUI is genuinely faster. The whole point: you get the complete Hummingbird workflow on a laptop, and it transfers unchanged to plain Kubernetes — no managed cloud on the path.");
}

/* ═════════════════ SECTION 2 — WORKING WITH THE IMAGES ══════════════════ */
divider("02", "Working with the images", "A diagram-led tour of the workflow.",
  "Now the hands-on arc, kept brief — one stop per topic, led by its diagram. Prerequisites and the registry model; pulling and inspecting; the debug-sidecar pattern and the broader debugging strategy; multi-stage builds; SBOMs and signing; CVE scanning; multi-service compose; the two layer-efficiency features; trusted libraries and provenance; and the distroless gotchas. Each has a runnable example.");

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · PREREQUISITES",
    "Prerequisites: the toolchain and the registry model",
    "01-prerequisites-toolchain",
    "Figure 1.1 — Podman, Skopeo, Syft, Grype, and Cosign over a single shared registry-auth file.");
  addNotes(s, "Setup pins the environment: Podman and Skopeo for images, Syft for SBOMs, Grype for scanning, Cosign for signatures — all sharing one registry-auth file. It also establishes the registry shortcuts used here: HB_REGISTRY=quay.io/hummingbird is the Project Hummingbird community org on Quay, RH_REGISTRY=registry.access.redhat.com is UBI and the toolbox, and the signed Red Hat path is used for verification. Note for GA: the Red Hat Hardened Images catalog now lives at images.redhat.com — browse there for the canonical image names and pull paths, and confirm them before a talk. One Fedora-44 note from the field: install Cosign from the upstream RPM, not dnf, which is currently broken there.");
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · PODMAN BASICS",
    "Pull and inspect — and meet the no-shell behavior",
    "03-podman-basics-pull-flow",
    "Figure 3.1 — podman pull resolves layers from the registry into local containers-storage, indexed by digest.");
  addNotes(s, "The first hands-on topic: pull an image, then read its manifest two ways — locally with podman inspect, remotely with skopeo inspect (no pull needed) — looking at the layer count and the provenance labels. Then the moment that surprises everyone from general-purpose bases: podman exec into a shell fails, because there is no shell. The image isn't broken — the application is the entrypoint. That single behavior reframes how you operate these images, and it sets up the debugging section.");
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · DEBUGGING",
    "The debug-sidecar pattern",
    "03-podman-basics-debug-sidecar",
    "Figure 3.2 — A toolbox container shares the target's PID and network namespaces; the target is untouched.");
  addNotes(s, `No shell means you don't exec into the container — you stand a second container next to it and share the target's kernel namespaces. The production container never changes, and the toolbox is thrown away after.

Steps to walk through:
1. Find the target: podman ps — note its name (say 'web').
2. Launch a toolbox that JOINS the target's namespaces:
   podman run -it --rm --pid=container:web --network=container:web registry.access.redhat.com/ubi9/toolbox
3. --pid=container:web shares the PID namespace, so ps/top in the toolbox see the target's processes. --network=container:web shares the network namespace, so curl 127.0.0.1:3000 in the toolbox hits the target's own ports and ss -ltnp lists its sockets.
4. For strace/gdb, add --cap-add=SYS_PTRACE; on SELinux-enforcing Fedora, relax the label for the debug container only (--security-opt label=disable).

Clarify the mechanism if asked: this is namespace JOINING, not a bind mount — the toolbox enters the same PID and network namespaces the kernel already created for the target, so it sees the same process table and the same loopback. Nothing is copied into the production image. On a cluster, kubectl debug does the identical trick against a pod. This is the single most important operational habit to teach.`);
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · DEBUGGING",
    "A four-layer debugging strategy",
    "08-debugging-layers",
    "Figure 8.1 — From cheap to invasive: logs, inspect, ephemeral sidecar, then cluster-side debug.");
  addNotes(s, "The sidecar is one rung on a ladder. Start cheap: logs and podman inspect answer most questions with zero intrusion. Escalate to the ephemeral debug sidecar when you need to see processes, sockets, or files. On a cluster, kubectl debug does the same namespace-sharing trick against a pod. The discipline is to climb the ladder in order — reach for the cheapest technique that answers the question, and only get invasive when you must.");
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · MULTI-STAGE BUILDS",
    "Multi-stage builds: builder image in, runtime image out",
    "04-multi-stage-builds-pattern",
    "Figure 4.1 — Compile in a -builder image; COPY --from copies just the artifact onto a minimal runtime.");
  addNotes(s, "This is the canonical Hummingbird workflow. Stage one uses a -builder image — the language plus compiler and package manager — to build the app. Stage two copies only the resulting artifact onto a minimal runtime image. Your production image inherits the small, hardened surface while the build still gets a full toolchain. Two rules surface immediately: only COPY in the runtime stage (no RUN — there's no shell), and set HOME in the builder so the non-root build user has somewhere to write. The Go example builds a static binary end to end in the demos.");
}

{
  const s = S();
  addCodeSlide(s, "WORKING WITH IMAGES · MULTI-STAGE BUILDS", "What that buys you, in a Containerfile", "Containerfile",
    [
      "# ---- build stage: full toolchain, thrown away ----",
      "FROM registry.access.redhat.com/hi/go:1.26-builder AS build",
      "WORKDIR /src",
      "COPY go.mod go.sum ./",
      "RUN go mod download",
      "COPY . .",
      "RUN CGO_ENABLED=0 go build -o /app ./cmd/server",
      "",
      "# ---- runtime stage: distroless — no compiler, no shell ----",
      "FROM registry.access.redhat.com/hi/go:1.26",
      "COPY --from=build /app /app",
      "USER 1001",
      'ENTRYPOINT ["/app"]',
    ],
    "COPY --from copies only the built binary; the compiler, module cache, and source never reach the shipped image.");
  addNotes(s, `The diagram shows the shape; this makes the payoff concrete. Read it as two images:
• Build stage (FROM ...-builder): the full toolchain — compiler, dnf, module cache. It does the work, then is discarded.
• Runtime stage (FROM hi/go:1.26): distroless — no compiler, no package manager, no shell.
• COPY --from=build copies ONLY the compiled binary across the boundary; the source, module cache, any build secrets, and the toolchain never reach the shipped image.

Why it matters:
• Attack surface — the production image has almost nothing to exploit: no compiler to build an exploit, no shell to run one.
• CVEs — the toolchain is where most of a base image's CVEs live; leaving it in the build stage is what keeps the runtime near-zero.
• Size / pull time — the runtime image is a fraction of the size.

Contrast a single-stage build: it ships the compiler, headers, and source — bigger, more CVEs, more to attack — for zero runtime benefit. Two rules the syntax enforces: only COPY in the runtime stage (no RUN — there's no shell), and in real use pin the base by digest, not a moving tag. CGO_ENABLED=0 makes a static binary, so the runtime needs no libc at all.`);
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · SBOM & SIGNING",
    "Three artifacts travel with the image",
    "05-sbom-and-signing-artifacts",
    "Figure 5.1 — Signature, SBOM attestation, and SLSA provenance — all on the same manifest, by digest.");
  addNotes(s, `Three things hang off the image manifest, all addressed by digest: a signature (who vouches for these exact bytes), an SBOM attestation (a signed bill of materials — what's inside), and a SLSA provenance attestation (how it was built). Hummingbird ships Red-Hat-signed versions on the signed registry path.

Where the SBOM actually lives — likely questions:
• From the registry (authoritative): the SBOM is attached to the image as a signed attestation. Pull it with cosign download sbom <image>, or verify it signed with cosign verify-attestation --type spdxjson <image>. Every Konflux-built Hummingbird image ships an SBOM plus SLSA provenance.
• From the image itself: RPM-based images carry their own package inventory inside — the rpm database (under /usr/lib/sysimage/rpm) plus Red Hat 'content manifests'. That's the 'internal DB'. It's present even in distroless images that have no rpm binary, which is exactly how a scanner enumerates packages without a shell.
• Vendor SBOMs: scanners generate their own SBOM from that inventory — Syft (for Grype), Trivy, and Docker Scout each produce one. So an image can carry the publisher's signed SBOM AND a tool-generated one; for trust decisions, prefer the signed publisher SBOM and verify it.

Red Hat's own SBOM analyzer is Trusted Profile Analyzer (RHTPA). In the demo we generate an SBOM with Syft, verify Red Hat's signature and SBOM, then sign an artifact ourselves — the same cosign either way.`);
}

{
  const s = S();
  addContentTitle(s, "WORKING WITH IMAGES · CVE SCANNING", "\u201cNear-zero CVE\u201d, measured");
  addBullets(s, [
    "Grype reads the image's package list, matches each against a vulnerability database, and reports by severity — with the caveat that a match isn't proof of an exploitable path, and the database moves daily.",
    "Scan a hardened image and a general-purpose image side by side: the hardened one is near-zero; the general-purpose one is typically tens to hundreds.",
    "Your own derived image shows what your app adds on top — the base stays clean, so the work shrinks to keeping your direct dependencies patched.",
    { text: "grype <image> --fail-on high gates a CI build automatically.", options: { bullet: false } },
  ], { fontSize: 16 });
  addNotes(s, `Where the claim becomes a number you can reproduce. Grype reads the package inventory, matches each entry against a vulnerability database, and reports by severity.

Two caveats to say out loud:
• A match is a reported CVE against a present package version — not proof the path is reachable. VEX (Vulnerability Exploitability eXchange) statements let a scanner suppress non-exploitable CVEs; Grype and Trivy both accept --vex, and Red Hat publishes VEX/CSAF data.
• The vuln DB updates daily and Grype refuses a stale one — so side-by-side numbers are only fair against the same DB. Run grype db update first.

We use Grype in the examples, but in production any of these read RHHI images fine — they all consume the in-image rpm inventory plus Red Hat advisories:
• Grype (Anchore) — CLI, SBOM-first, pairs with Syft. What the demos use.
• Trivy (Aqua) — the most widely used CLI scanner; images, filesystems, IaC, Kubernetes; uses Red Hat advisories + CPE content sets for accurate RHEL matching.
• Clair v4 (Red Hat) — service-based; the default scanner in Red Hat Quay / Quay.io and in Harbor.
• Red Hat Advanced Cluster Security (RHACS) Scanner V4 — the OpenShift-native option; merges the StackRox scanner with Clair v4, and also verifies cosign signatures at admission. The production gate.
• Commercial: Snyk, Prisma Cloud, Aqua, Docker Scout, Anchore Enterprise.

Accuracy note: RHEL CVE matching relies on per-layer content manifests, so don't flatten or merge layers (e.g. podman export) before scanning, or the CPE mapping breaks and you get false results.`);
}

{
  const s = S();
  addCodeSlide(s, "WORKING WITH IMAGES · CVE SCANNING", "The same claim, from the command line", "zsh",
    [
      "# keep the vuln DB fresh — grype refuses a stale one",
      "grype db status || grype db update",
      "",
      "# hardened vs general-purpose, side by side",
      "grype registry.access.redhat.com/hi/nginx:1",
      "grype docker.io/library/nginx:latest",
      "",
      "# or scan the signed SBOM instead of the image, and gate CI",
      "cosign download sbom registry.access.redhat.com/hi/nginx:1 > nginx.sbom.json",
      "grype sbom:nginx.sbom.json --fail-on high   # non-zero exit fails the build",
    ],
    "Scan the image directly, or scan its signed SBOM; --fail-on turns either into a CI gate.");
  addNotes(s, `The reproducible version of the previous slide. Three things to show live:
• grype db update first — Grype won't scan against a stale database, and a fair comparison needs both images scanned against the same DB.
• The side-by-side is the moment: the hardened nginx comes back at or near zero; docker.io/library/nginx is typically tens to hundreds.
• You can scan the image, or scan its signed SBOM — cosign download sbom ... then grype sbom:.... Scanning the SBOM is what CI usually does: it's faster and needs no pull. --fail-on high makes grype exit non-zero, failing the pipeline step.

The same commands work against your own derived image — the base stays clean, so what shows up is what your app added. Tool choice is covered on the previous slide's notes (Trivy, Clair, and RHACS Scanner V4 all read these images too).`);
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · PODMAN COMPOSE",
    "Multi-service apps with Podman Compose",
    "07-podman-compose-stack",
    "Figure 7.1 — A hardened web service, a database, and an OpenTelemetry collector, wired with compose.");
  addNotes(s, "Compose assembles the single-image work into a multi-service application — here a hardened web service, a database, and an OpenTelemetry collector. Two gotchas live in this section and bite people: healthchecks must use a tool that's actually in the distroless image (the language interpreter, not /bin/test), and Hummingbird's Postgres follows upstream env-var names — POSTGRES_PASSWORD, not the older sclorg POSTGRESQL_PASSWORD. Both show up again in the gotchas demo.");
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · EFFICIENT LAYERS",
    "zstd:chunked — pull only the bytes that changed",
    "09-zstd-chunked-layer-format",
    "Figure 9.1 — zstd:chunked makes layers seekable, so clients fetch only changed chunks.");
  addNotes(s, `Why staying current is cheap — part one. A normal OCI layer is a single gzip blob: change one file and the client re-pulls the whole layer.

• zstd:chunked stores the layer compressed with zstd and keeps a table of content-addressed chunks plus a manifest of which chunk holds which file.
• On pull, the client compares chunk digests against what it already has and fetches only the chunks that changed; unchanged chunks come from cache.
• zstd also decompresses much faster than gzip, so even a full pull is quicker.
• It's a standard OCI/containers-storage feature, not Hummingbird-specific — but it pairs perfectly with 'rebuild, don't patch': a rebuild that touched one package costs roughly that package's bytes, not the whole image.

Good moment to pre-empt 'won't constant rebuilds hammer my bandwidth?' — no, and this is why.`);
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · EFFICIENT LAYERS",
    "chunkah — content-based layer splitting",
    "10-chunkah-layer-split",
    "Figure 10.1 — Layers grouped by package, so a package update invalidates only its own layer.");
  addNotes(s, `Why staying current is cheap — part two, and it composes with zstd:chunked. Normally each Containerfile instruction becomes a layer, so unrelated packages share a layer and any change re-pulls all of them.

• chunkah splits the filesystem into layers by the package each file belongs to, instead of by build step.
• A one-package security update changes only that package's layer digest; every other layer keeps its digest and stays cached, so clients re-pull just the changed package.
• It's why podman history on a Hummingbird image shows a content-based split (many small package layers) — and why a hardened image can have MORE layers than a general-purpose one. More layers here is a feature, not bloat.
• Together: chunkah decides the layer boundaries (per package); zstd:chunked makes each layer's bytes individually fetchable. The cost of staying current tracks what actually changed.

Nice to show live: podman history of a hardened image in demo 1.`);
}

{
  const s = S();
  addContentTitle(s, "WORKING WITH IMAGES · TRUSTED LIBRARIES", "Provenance, extended to your dependencies");
  addBullets(s, [
    "The base image gives trust at the container layer; your app still runs whatever you pulled from PyPI — a public, unaudited index.",
    "Red Hat Trusted Libraries is a pip-compatible index of curated Python packages, rebuilt from source in Red Hat's Konflux pipeline with SLSA Level 3 provenance and signed attestations (via Red Hat Trusted Artifact Signer).",
    "Point pip at packages.redhat.com/trusted-libraries, keep PyPI as a fallback, and verify a package's provenance before installing.",
    { text: "Tech Preview (since Feb 2026) and Python-only today, with npm and Java planned; now part of Red Hat Advanced Developer Suite. The upstream community project is Calunga.", options: { bullet: false }, muted: true },
  ], { fontSize: 16 });
  addNotes(s, `Provenance shouldn't stop at the image. Your app still pulls dependencies from PyPI — a public passthrough that re-signs nothing — so the trust you established at the container layer evaporates at the dependency layer. Trusted Libraries closes that gap.

Define the terms (the audience may be new to them):
• Provenance — a signed, machine-readable record of HOW and from WHAT an artifact was built: source repo + commit, the builder, inputs, parameters. A signature says WHO vouches for the bytes; provenance says WHERE they came from and HOW. You verify both.
• Konflux — Red Hat's open-source, Tekton-based build pipeline ('software factory') focused on supply-chain security; it builds Hummingbird and emits an SBOM + SLSA provenance for every image.
• SLSA Level 3 provenance — the build ran on a hardened, isolated, hosted service that produced signed provenance that can't be forged and can be verified as authentic (versus Level 1, which is just unsigned build metadata).
• Red Hat Trusted Artifact Signer (RHTAS) — Red Hat's enterprise, self-managed deployment of Sigstore (cosign / fulcio / rekor); it's how these packages are signed, and what you'd run in-house to sign your own.

Usage: point pip at packages.redhat.com/trusted-libraries with PyPI as fallback, and verify a package's provenance before installing. Status to state plainly: Tech Preview since Feb 2026, Python-only (npm and Java planned), now part of Red Hat Advanced Developer Suite; the index is authenticated; the upstream community project is Calunga. The next slide is the picture.`);
}

{
  const s = S();
  addDiagramSlide(s, "WORKING WITH IMAGES · TRUSTED LIBRARIES", "Trust, all the way down to your dependencies",
    "13-trusted-libraries-provenance",
    "Figure 13.1 — The base image is already trusted; Trusted Libraries extends the same provenance to your Python packages.");
  addNotes(s, `One picture for the value proposition. The hardened base image is already trusted — signed, with an SBOM and SLSA provenance. Your application sits on top with its Python dependencies, and those have two possible sources:
• PyPI — the usual index: public, unsigned, unaudited. This is the gap (dashed): you verified the base, then pulled unverified code on top of it.
• Red Hat Trusted Libraries — the same packages rebuilt from source in Konflux, carrying SLSA Level 3 provenance and signatures (via Trusted Artifact Signer) you can verify before install (solid).

The point to land: it's the exact same verify-before-you-trust habit you already apply to the image, now extended one layer down to the dependencies your app actually runs.`);
}

{
  const s = S();
  addContentTitle(s, "WORKING WITH IMAGES · GOTCHAS", "Distroless gotchas — assumptions made visible");
  addTwoColBullets(s,
    [
      { text: "Build & runtime", options: { bullet: false, bold: true } },
      "RUN in a runtime stage fails — no /bin/sh.",
      "\u201cPermission denied\u201d on /.cache — set HOME in the builder.",
      "python vs python3 — the bare alias is gone.",
    ],
    [
      { text: "Config & operations", options: { bullet: false, bold: true } },
      "Postgres needs POSTGRES_*, not POSTGRESQL_*.",
      "\u201cConnection reset\u201d — curl 127.0.0.1, not localhost (IPv6).",
      "Past ~5 COPYed libraries? Switch to UBI.",
    ]);
  addCaption(s, "None are bugs — each is the absence of something you didn't know you relied on.");
  addNotes(s, `The gotchas are implicit ecosystem assumptions made visible against a minimal runtime — not defects. The closing demo trips each on purpose. Land these:
• RUN needs a shell → do shell work in the -builder stage, COPY the result into runtime.
• Build tools want HOME → set it, or caches resolve to / and fail for the non-root user.
• The bare 'python' alias is gone → use python3 in CMD/ENTRYPOINT.
• Hummingbird's Postgres uses upstream env names (POSTGRES_PASSWORD), not sclorg (POSTGRESQL_PASSWORD).
• localhost resolves to IPv6 (::1) first → test against 127.0.0.1, or bind dual-stack.

The biggest real-world gotcha — native-extension stacks: SciPy / NumPy / pandas and most ML inference need shared libraries the distroless runtime omits (libstdc++, libgomp, libgfortran, BLAS/LAPACK, libquadmath…). You can COPY them in one by one, but past a handful you've hand-rebuilt a chunk of UBI's userland — and those hand-copied libraries are NOT in the image's SBOM and NOT CVE-tracked by Red Hat, which quietly undoes the reason you chose a hardened image. The practical rule: hardened runtime for Go static binaries, JVM apps, and light or pure-Python services; reach for UBI when the accommodation list gets long. Mixing per stage is normal — build on UBI, deploy on hardened where it fits. This is Gotcha F in the demo, and it's the most useful 'when NOT to use this' guidance you can give.`);
}

/* ═══════════════════ SECTION 3 — THE DEMO WALKTHROUGH ═══════════════════ */
divider("03", "The demo walkthrough", "Eight command-line demos, live.",
  "We finish at the terminal. There are eight demos that mirror the sections we just toured. Each narrates what it's about to do, stops so you can talk over the command on screen, runs it live, and stops again before the next one. They run individually or back-to-back as a guided walkthrough, entirely on Podman, locally. This is the part where every claim in the deck becomes something the room watches happen.");

{
  const s = S();
  addContentTitle(s, "DEMOS · HOW THEY RUN", "Narrate \u2192 stop \u2192 run \u2192 stop");
  addBullets(s, [
    "Eight demos under demos/, runnable individually or as one guided walkthrough.",
    "Each demo explains a step, stops for Enter so you can narrate, runs the command live, then stops again before the next.",
    "Nothing aborts on stage: a slow pull or unreachable registry degrades to a short note and the demo continues.",
    "Self-cleaning: every demo removes the containers, images, and temp files it created on exit.",
  ], { fontSize: 16 });
  addNotes(s, "Set expectations before the live portion. The interaction is a rhythm: narrate the upcoming command, stop on Enter, run it, stop again — so you control pacing and the audience reads each command before it executes. The engine is built for a stage: network-touching steps are allowed to fail soft, so a flaky conference connection never kills the talk. And each demo cleans up after itself, so re-runs are idempotent and your machine stays tidy. Pre-pull the images beforehand with run.sh check.");
}

{
  const s = S();
  addContentTitle(s, "DEMOS · 1\u20134", "Pull, debug, compare, build");
  addStatusTable(s, [
    { code: "Demo 1", name: "Pull & inspect", purpose: "Manifest via podman + skopeo, layer count, labels, the no-shell moment." },
    { code: "Demo 2", name: "Debug sidecar", purpose: "An ephemeral toolbox sharing a shell-less container's PID/network namespaces." },
    { code: "Demo 3", name: "Minimal vs not", purpose: "Size, layer count, and contents against a general-purpose image." },
    { code: "Demo 4", name: "Multi-stage build", purpose: "Builder compiles; runtime ships only the binary (the Go example)." },
  ], { colW: [1.40, 3.10, 7.59], rowH: 0.74 });
  addNotes(s, "The first four demos map onto the early sections. Demo 1 pulls a hardened curl image, inspects it both ways, points at the content-based layers, and then fails to exec a shell — the no-shell moment, live. Demo 2 runs a hardened nginx, fails to exec into it, then attaches a toolbox sidecar that sees its processes and reaches it over shared localhost. Demo 3 puts hardened and stock nginx side by side on size, layers, and contents. Demo 4 builds the Go example end to end and proves the toolchain didn't come along.");
}

{
  const s = S();
  addContentTitle(s, "DEMOS · 5\u20138", "Sign, scan, verify, trip the wires");
  addStatusTable(s, [
    { code: "Demo 5", name: "SBOMs & signing", purpose: "Syft SBOM, verify Red Hat's signature + SBOM, sign your own artifact (offline)." },
    { code: "Demo 6", name: "CVE scanning", purpose: "Grype: hardened vs stock vs your image, plus a --fail-on high CI gate." },
    { code: "Demo 7", name: "Provenance", purpose: "Image SLSA provenance, then Trusted Libraries for Python dependencies." },
    { code: "Demo 8", name: "Distroless gotchas", purpose: "RUN-needs-a-shell, python vs python3, Postgres env names, and more — shown failing then fixed." },
  ], { colW: [1.40, 3.10, 7.59], rowH: 0.74 });
  addNotes(s, "The back four map onto the trust and operations sections. Demo 5 generates an SBOM, verifies Red Hat's signature and shipped SBOM on the signed path, then signs an artifact locally with no registry push. Demo 6 is the CVE payoff — real Grype numbers side by side and a CI gate. Demo 7 verifies image provenance as a reliable anchor, then walks the Trusted Libraries flow with graceful fallback since it's Tech Preview. Demo 8 trips each gotcha on purpose and shows the fix. Note: demos 5 and 7 verify against the signed registry.access.redhat.com/hi path.");
}

{
  const s = S();
  addCodeSlide(s, "DEMOS · RUNNING IT", "Drive it from the repo root", "zsh",
    [
      "# preflight: shows tools on PATH + registry settings, and a pre-pull tip",
      "./demos/run.sh check",
      "",
      "# the full guided walkthrough, in order",
      "./demos/run.sh all",
      "",
      "# or one demo at a time",
      "./demos/run.sh 4",
      "./demos/04-multi-stage-build.sh   # each demo is runnable on its own",
    ],
    "Bash scripts with a bash shebang — they run fine from a zsh prompt.");
  addNotes(s, "Driving it is simple. run.sh check is the first thing to run in a new room: it lists which tools are on PATH, prints the registry settings, and gives you a ready-made podman pull line so nothing stalls on the venue wifi. run.sh all is the guided walkthrough; run.sh <n> runs a single demo; and each NN-*.sh is independently executable. The scripts are bash with a bash shebang, so they run cleanly from the zsh prompt we present from. Registry overrides — for example pointing at the early-access org — are environment variables set before launching.");
}

/* ═══════════════ SECTION 4 — SUPPLY CHAIN SECURITY (CLOSE-OUT) ═══════════════ */
divider("04", "Supply chain security", "Where a hardened base fits the bigger threat model.",
  "This close-out borrows the canonical container supply-chain threat model from Liz Rice's Container Security (2nd edition, chapter 7) and reframes it for Podman, OpenShift, and RHEL. The goal for the audience: Hummingbird is, in large part, an answer to this model — it closes the hardest vectors by construction — while source/Containerfile integrity, host and platform hardening, and the admission gate stay the operator's job.");

{
  const s = S();
  addDiagramSlide(s, "SUPPLY CHAIN · THE PROBLEM",
    "Where the supply chain gets attacked",
    "18-supply-chain-security-the-chain",
    "Figure 18.1 — The container supply chain, and where it gets attacked.");
  addNotes(s, `Walk the chain left to right and name the attack at each stage. This is the generic model — no Hummingbird yet.
1. Source code — tampered source: someone with repo access or stolen credentials changes the app before it's ever built. Defended by branch protection, RBAC, signed commits, review.
2. Code repo + Containerfile — tampered build file: a malicious RUN line is arbitrary code execution at build time; it can pull malware, read build secrets, or probe the build network. Treat Containerfile edits like privileged code.
3. CI build — three vectors converge here: a vulnerable or poisoned BASE image (FROM); a vulnerable or confused DEPENDENCY pulled during the build (dependency confusion — a wrong-registry or typo'd package); and BUILD-TIME tampering / a compromised build host that injects a backdoor even from clean source.
4. Registry — tampered stored image: the image is swapped or modified at rest after it was built.
5. Pull → Deploy — intercepted pull (image altered in transit) and malicious deployment definition: a one-character change to a registry hostname in the YAML silently runs a different image.

Set up the next slide: most of these are about trusting inputs you didn't build and can't see — exactly what signing, provenance, and a minimal verified base address.`);
}

{
  const s = S();
  addDiagramSlide(s, "SUPPLY CHAIN · THE ANSWER",
    "The same chain, with the Hummingbird answer",
    "18-supply-chain-security-attack-vectors",
    "Figure 18.2 — Attack vectors and the Hummingbird answer at each stage, on Podman/Konflux/OpenShift.");
  addNotes(s, `Same chain, now the Hummingbird / Red Hat answer at each stage — map them one to one:
1. Source — still yours, but smaller: branch protection, RBAC, signed commits. Hummingbird doesn't own your repo.
2. Containerfile — pin the base by digest (not a moving tag) and review every RUN/COPY. Hummingbird gives a trustworthy FROM; it can't fix an insecure Containerfile on top.
3. Build — the big one: builds run in Konflux, a hardened, isolated pipeline that emits SLSA 3 signed provenance; the base is near-zero-CVE and distroless (fewer dependencies to be vulnerable); and for your own code, Trusted Libraries extends the same provenance to Python packages. Vulnerable-base, vulnerable-deps, and build-tampering all move from 'trust us' to 'here's signed evidence'.
4. Registry — the image carries a cosign signature + signed SBOM + signed provenance on the signed /hi path. A swapped or modified image fails verification.
5. Pull/Deploy — verify on pull with podman + cosign; enforce cluster-wide with an OpenShift admission policy (RHACS / sigstore admission) so an unsigned or unverified image won't run — that closes the malicious-YAML vector.

The framing to land: Hummingbird closes the middle of the chain by construction; you still own the two ends — source/Containerfile and deploy/platform.`);
}

{
  const s = S();
  addDiagramSlide(s, "SUPPLY CHAIN · RUNTIME SURFACE",
    "Defense in depth — and where the image helps",
    "18-supply-chain-security-layers",
    "Figure 18.3 — The layered runtime attack surface; the hardened image shrinks the image-and-app cluster, not the platform.");
  addNotes(s, `The pipeline view was build-and-delivery; this is runtime — defense in depth. Walk the layers from outside in and pair each exploit with the Red Hat control that addresses it:
• Insecure networking (exposed or cleartext services) — OpenShift NetworkPolicy, service mesh / TLS. Hummingbird doesn't change this.
• Misconfigured host (a weak RHEL host undermines everything above it) — RHEL hardening, SELinux enforcing, OpenSCAP CIS/STIG compliance, a minimal host footprint.
• Code exploits against the runtime/orchestrator — keep the platform patched; SELinux + seccomp confine what a compromised process can do.
• Compromised container image (swapped or poisoned) — cosign signature verification at admission (RHACS): fails verification, doesn't run.
• Poorly configured image — distroless removes the foot-guns (no shell, no package manager, non-root UID 65532), so there's far less to misconfigure.
• Exposed secrets / code exploits inside the container — a minimal image gives an intruder almost nothing to use (no shell, no curl, no package manager) and fewer packages mean fewer exploitable paths; pair with real secret management (never bake secrets into the image).
• Container escape — rootless Podman, dropped capabilities, seccomp, SELinux, and OpenShift SCCs constrain the blast radius.

The division to state: the hardened image shrinks the image-and-app cluster in the middle; the RHEL/OpenShift platform handles the host, network, and isolation around it. Defense in depth, not one silver bullet.`);
}

{
  const s = S();
  addContentTitle(s, "SUPPLY CHAIN · DIVISION OF LABOUR", "What Hummingbird closes — and what's still yours");
  addStatusTable(s, [
    { code: "Vulnerable base", name: "Hummingbird", purpose: "Near-zero-CVE hardened base, rebuilt continuously" },
    { code: "Vulnerable deps", name: "Hummingbird + TL", purpose: "Distroless minimalism; Trusted Libraries for Python" },
    { code: "Build integrity", name: "Hummingbird", purpose: "SLSA 3 hermetic Konflux build, signed provenance" },
    { code: "Image authenticity", name: "Hummingbird", purpose: "cosign signature + SBOM + provenance on /hi" },
    { code: "Source / file", name: "You", purpose: "Branch protection, signed commits, pin base by digest" },
    { code: "Deploy / platform", name: "You", purpose: "OpenShift admission control; host & network hardening" },
  ], { colW: [2.75, 2.85, 6.49], rowH: 0.62 });
  addCaption(s, "Verify on pull (podman + cosign); enforce for every deploy with an OpenShift admission policy.");
  addNotes(s, "The summary to land, and a good place to end an admin talk. Hummingbird owns the image — vulnerable base, vulnerable dependencies, build integrity, image authenticity — the part that's genuinely hard to do yourself and that you get for free. You own the edges — source and Containerfile integrity, platform hardening, and the admission gate that enforces verification for every deploy. The practical close: verify on pull with podman + cosign, and enforce it cluster-wide with an OpenShift admission policy so no one can route around the check — that's what closes the malicious-deployment-definition vector. A near-zero-CVE distroless base is the strongest single move on the supply chain precisely because it collapses the vectors that are hardest to defend one at a time.");
}

{
  const s = S();
  addContentTitle(s, "CLOSING", "Where this leaves you");
  addBullets(s, [
    "Hummingbird = rebuild-don't-patch, distroless, near-zero-CVE images on the existing Red Hat trust chain.",
    "The whole workflow runs locally on Podman — pull, inspect, build multi-stage, SBOM, sign, scan, verify provenance.",
    "\u201cNear-zero CVE\u201d is a scan away from being your own measurement; the job that remains is keeping your dependencies patched.",
    "Match the runtime to the workload: Hummingbird where minimalism helps, UBI where breadth does.",
    { text: "Docs & demos: github.com/patterncatalyst/hummingbird-tutorial \u00b7 patterncatalyst.github.io/hummingbird-tutorial", options: { bullet: false }, muted: true },
  ], { fontSize: 15 });
  addNotes(s, "Recap the arc and point to where to go deeper. One idea drives everything — rebuild instead of patch — and it gives you distroless, near-zero-CVE images on a trust chain you may already rely on. The entire workflow fits on a laptop with Podman. The strongest closing note for an admin audience: near-zero CVE isn't something to take on faith — it's one Grype command away from being your own measurement, and the work that remains is the tractable part, keeping your own dependencies current. And it's not all-or-nothing: use Hummingbird where minimalism wins and UBI where breadth does. Everything in this deck — the workflow, runnable examples, and the demos — lives in the project repo and site.");
}

/* ═══════════════════════════════ THANK YOU ═════════════════════════════ */
{
  const s = pres.addSlide();
  pageNum += 1;
  s.background = { color: COLOR.white };
  try { s.addImage({ path: `${ASSETS}/cover-panel.png`, x: 0, y: 0, w: W, h: 7.5 }); } catch (e) {}
  s.addText("RED HAT HARDENED IMAGES · RHHI", { x: 6.00, y: 1.98, w: 6.90, h: 0.34,
    fontFace: FONT.title, fontSize: 14, bold: true, color: COLOR.red, charSpacing: 6, align: "left", valign: "middle" });
  s.addText("Thank you", { x: 5.95, y: 2.42, w: 6.95, h: 1.30,
    fontFace: FONT.title, fontSize: 54, bold: true, color: COLOR.ink, align: "left", valign: "top" });
  s.addText("Pull an image, scan it, verify it — the whole workflow runs locally on Podman. The slides, runnable examples, and the eight demos are all linked below.",
    { x: 6.00, y: 3.85, w: 6.80, h: 1.10, fontFace: FONT.body, fontSize: 17, italic: true, color: COLOR.caption, align: "left", valign: "top" });
  s.addText([
    { text: "github.com/patterncatalyst/hummingbird-tutorial", options: { breakLine: true, color: COLOR.ink } },
    { text: "images.redhat.com  ·  the GA catalog and canonical image names", options: { color: COLOR.caption } },
  ], { x: 6.00, y: 5.05, w: 6.80, h: 0.80, fontFace: FONT.mono, fontSize: 12, align: "left", valign: "top", lineSpacingMultiple: 1.3 });
  try { s.addImage({ path: `${ASSETS}/logo-candidate-2.png`, x: 11.10, y: 6.80, w: 1.55, h: 0.37 }); } catch (e) {}
  addNotes(s, "Close, then open the floor. The single line to leave them with: near-zero CVE isn't a slogan to take on faith — it's one Grype command away from being their own measurement, and the workflow they just saw runs entirely on Podman on a laptop. Point them at the repo for the runnable examples and the eight demos, and at images.redhat.com for the GA catalog and the canonical image names and pull paths.");
}

pres.writeFile({ fileName: OUT })
  .then(p => console.log("WROTE", p))
  .catch(e => { console.error(e); process.exit(1); });
