---
title: Supply chain security — the whole chain, end to end
order: 18
description: A capstone that places everything the tutorial built — hardened base images, SBOMs, signing, provenance, scanning, Trusted Libraries — onto the standard container supply-chain threat model, reframed for Podman, OpenShift, and RHEL. Shows which attack vectors a near-zero-CVE distroless image neutralizes by construction, and, just as importantly, which ones it does not.
duration: 30 minutes
---

Every previous chapter solved one piece of a larger problem. This
one steps back and names the problem.

Supply chain security is the discipline of making sure the software
you run is the software you intended to run — built from source you
trust, by a build system you trust, and delivered to you without
tampering. The canonical treatment for containers is Liz Rice's
*Container Security* (2nd edition, O'Reilly, 2025), chapter 7. This
chapter borrows her threat model and maps it onto the Hummingbird
world: Podman and Buildah instead of Docker, `Containerfile`
instead of `Dockerfile`, `registry.access.redhat.com` and OpenShift
instead of a generic registry and orchestrator, and a near-zero-CVE
distroless base instead of a general-purpose one.

The headline: **Red Hat Hardened Images are, in large part, an
answer to this threat model.** Most of the attack vectors below are
neutralized by construction when the base image is built the way
Hummingbird builds it. A few are not, and being honest about which
is the whole point of this chapter — an over-trusted hardened image
is its own risk.

## The supply chain, and where it gets attacked

A container image is assembled from a chain of inputs — source
code, a `Containerfile`, a base image, language packages, OS
packages — and then built, stored, and deployed. Each hand-off is
a place an attacker can interfere.

{% include excalidraw.html
   file="18-supply-chain-security-the-chain"
   alt="A left-to-right pipeline — source code, code repo with a Containerfile, CI build, registry, deployment — with the classic supply-chain attack vectors labelled above and below each stage"
   caption="Figure 18.1 — The container supply chain, and where it gets attacked" %}

Reading left to right, the classic vectors are:

- **Tampered source** — someone modifies the application source
  before it is built.
- **Tampered `Containerfile`** — a build instruction is altered to
  add malware, exfiltrate build secrets, or attack the build host.
  A `RUN` line is arbitrary code execution on the builder.
- **Vulnerable base image or dependencies** — the `FROM` image, or
  an OS/language package pulled during the build, already contains
  exploitable code (or the wrong package entirely — *dependency
  confusion*).
- **Build tampering / compromised build host** — the build
  environment itself is subverted, so a clean source tree still
  produces a poisoned image.
- **Image tampered in the registry** — the stored image is swapped
  or modified after it was built.
- **Intercepted pull** — the image is altered in transit between
  registry and host.
- **Malicious deployment definition** — the Kubernetes/OpenShift
  YAML is changed to run a different (malicious) image; a one-
  character change to a registry hostname is enough.

This is the same model whether you build with Docker, Podman, or
anything else. What changes with Hummingbird is how many of these
vectors are closed before you write a line of policy.

## Where Hummingbird changes the picture

Figure 18.2 overlays the Hummingbird answer on that same chain:
the attack vectors run along the top, and the mitigation at each
stage runs along the bottom.

{% include excalidraw.html
   file="18-supply-chain-security-attack-vectors"
   alt="The same supply-chain pipeline, reframed for Buildah and Konflux, a signed Red Hat registry path, and OpenShift, with the attack vectors along the top and the Hummingbird mitigation at each stage along the bottom"
   caption="Figure 18.2 — Attack vectors and the Hummingbird answer at each stage, on Podman/Konflux/OpenShift" %}

Each mitigation along the bottom row was built and demonstrated
earlier in this tutorial:

| Attack vector | What closes it | Covered in |
|---|---|---|
| Vulnerable base image | Near-zero-CVE hardened base, rebuilt continuously | [§2](../02-introduction/), [§6](../06-cve-scanning/) |
| Vulnerable dependencies | Distroless minimalism (fewer packages to be vulnerable) + Trusted Libraries for Python deps | [§6](../06-cve-scanning/), [§13](../13-trusted-libraries/) |
| Build tampering / compromised build host | SLSA 3 hermetic builds on Konflux; signed, verifiable provenance | [§2](../02-introduction/), [§5](../05-sbom-and-signing/) |
| Image tampered in registry | cosign signature + SBOM + SLSA provenance attestations on the signed `/hi` path | [§5](../05-sbom-and-signing/) |
| Intercepted pull | Verify the signature and attestations on pull with `podman` + `cosign` | [§5](../05-sbom-and-signing/) |
| Malicious deployment definition | OpenShift admission control / a sigstore admission policy that refuses unsigned or unverified images | this chapter |

The throughline is the same idea you met in §2 and §5: the image
does not merely *assert* it is safe, it carries **signed evidence**
you can check. A hardened base turns three of the worst vectors —
vulnerable base, vulnerable dependencies, build tampering — from
"trust us" into "verify it yourself," and the minimalism means
there is simply less inside the image to be vulnerable in the first
place. The empirical version of that claim is the scan you ran in
[§6](../06-cve-scanning/): the hardened image at or near zero,
the general-purpose image in the hundreds.

> **What Hummingbird does *not* close.** Look again at the left of
> the diagram. Tampered source and a tampered `Containerfile` are
> *yours* to defend: branch protection and RBAC on the repo, signed
> commits, code review of every new `RUN`/`COPY`, and pinning your
> base image by digest rather than tag. Hummingbird gives you a
> trustworthy `FROM`; it cannot stop you from writing an insecure
> `Containerfile` on top of it.

## The layered attack surface

The pipeline view covers *build and delivery*. At *runtime*, the
relevant picture is defence in depth: a running container sits
inside a stack of boundaries, and an attacker can target any layer.

{% include excalidraw.html
   file="18-supply-chain-security-layers"
   alt="Nested boxes from the physical machine through network, VM, RHEL host OS, the Podman/CRI-O runtime and OpenShift orchestrator, down to the container network, the container, the hardened image and the application, with attack vectors labelled at each layer"
   caption="Figure 18.3 — The layered runtime attack surface (after Liz Rice, Container Security 2e), and where the hardened image shrinks it" %}

The hardened image directly shrinks the cluster of vectors aimed at
the image and what runs in it:

- **Compromised image** — defeated by signing and verification: a
  swapped image fails `cosign verify` against Red Hat's key.
- **Poorly configured image** — distroless removes most of the
  foot-guns: no shell, no package manager, a non-root default user
  (UID 65532 where technically possible), so there is far less to
  misconfigure.
- **Exposed secrets / code exploits** — fewer packages means fewer
  exploitable code paths, and with no shell or tools baked in, an
  attacker who does land in the container has very little to work
  with. This is the practical meaning of "small attack surface."

What the image **cannot** fix is everything outside it. A
misconfigured RHEL host, insecure networking, and container escape
are addressed by the *platform*, not the base image: rootless
Podman, SELinux, seccomp and capability restrictions, and OpenShift
SCCs and network policies. The hardened image is one strong layer;
it is not the whole onion.

## Verifying on Podman, enforcing on OpenShift

Two practical habits turn all of this from theory into a gate.

**On pull, verify — don't just trust the tag.** This is the §5
flow, recapped: confirm the signature, then inspect the signed
attestations.

```bash
SIGNED="registry.access.redhat.com/hi/nginx:1"

# 1. Signature: did Red Hat sign this exact image?
cosign verify \
  --key "https://security.access.redhat.com/data/63405576.txt" \
  --insecure-ignore-tlog \
  "$SIGNED" >/dev/null && echo "signature OK"

# 2. What signed supply-chain metadata is attached?
cosign download attestation "$SIGNED" \
  | jq -rs '.[] | (.payload | @base64d | fromjson | .predicateType)' \
  | sort -u
# -> https://slsa.dev/provenance/v0.2   (how it was built)
#    https://spdx.dev/Document           (what's inside)
```

Verify against the **signed** `registry.access.redhat.com/hi/`
path. The `quay.io/hummingbird` mirror is unsigned by design, so
there is nothing there for `cosign` to check. (See
[§5](../05-sbom-and-signing/) for the full signing and
verification walkthrough, including the SLSA-provenance predicate
nuance — the `v0.2` predicate URI is why a bare
`--type slsaprovenance` does not match.)

**At deploy time, enforce it.** Verifying by hand proves the chain
holds once; an admission controller makes it hold for *every*
deployment, so no one can route around the check. In OpenShift,
that is the sigstore admission policy (or a policy engine such as
Kyverno or OPA Gatekeeper) configured to reject any image that is
not signed by the expected identity, not scanned, or not from an
approved registry. The same `policy.json` you wrote in §5 is the
single-host version of this idea; admission control is the
cluster-wide version.

The point of an admission gate is that it closes the *malicious
deployment definition* vector from Figure 18.1: it does not matter
what an attacker writes in a YAML file if the cluster refuses to
run an image that fails verification.

## What this buys you, honestly

Put the two figures together and the division of labour is clear:

- **Hummingbird owns the image.** Vulnerable base, vulnerable
  dependencies, build integrity, and image authenticity are handled
  by construction — near-zero CVE, distroless, hermetically built
  to SLSA 3, signed with verifiable SBOM and provenance. This is
  the part that is genuinely hard to do yourself, and the part you
  get for free.
- **You own the edges.** Source and `Containerfile` integrity, the
  host and platform hardening, network policy, secrets management,
  and the admission gate that enforces verification are yours. The
  hardened image makes these *easier* — there is less to scan, less
  to misconfigure, less to exfiltrate — but it does not make them
  someone else's job.

A near-zero-CVE distroless base is the strongest single move you
can make on the supply chain, precisely because it collapses the
vectors that are hardest to defend individually. It is not, and
does not claim to be, the entire defence.

## Verify before moving on

You should be able to:

- sketch the container supply chain and name the attack vector at
  each stage, in Podman/OpenShift terms,
- say which vectors a Hummingbird base image closes by
  construction, and which remain your responsibility,
- verify both the signature and the attached attestations of a
  Hummingbird image on pull,
- explain why an OpenShift admission policy is what closes the
  malicious-deployment-definition vector, and
- describe the layered runtime attack surface and where the
  hardened image does — and does not — help.

## Where to go next

This is the end of the tutorial's through-line. From here:

- Re-run the [demo suite](https://github.com/patterncatalyst/hummingbird-tutorial/tree/main/demos)
  end to end — the eight command-line demos are the moving-picture
  version of everything in these chapters, and demo 7 in particular
  is this chapter made executable.
- Revisit [§5](../05-sbom-and-signing/) and
  [§6](../06-cve-scanning/) with the threat model in mind; the
  commands land differently once you can name the vector each one
  closes.
- For the platform-hardening edges this chapter deliberately left
  out — rootless Podman, SELinux, OpenShift SCCs, network policy —
  Liz Rice's *Container Security* (2nd edition) is the reference to
  read next; this chapter only borrowed its chapter 7.

The source for this page is in
[`_docs/18-supply-chain-security.md`](https://github.com/patterncatalyst/hummingbird-tutorial/blob/main/_docs/18-supply-chain-security.md).
