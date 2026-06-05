#!/usr/bin/env bash
# Demo 1 — Pull & inspect: manifest via podman + skopeo, layers, labels, no shell.
#          (layer counts + labels), and watch the no-shell behaviour.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib/_demo.sh"

demo_title 1 "Pull & inspect a hardened image — layers, labels, no shell"
require_tools podman skopeo jq || exit 0

IMG="$HB_REGISTRY/curl:latest"

demo_intro "Red Hat Hardened Images (Project Hummingbird) are ordinary OCI \
images — they pull and run with the tools you already use. We'll pull the \
hardened 'curl' image, read its manifest two ways (locally with podman, \
remotely with skopeo), count its layers, read its provenance labels, and \
then meet the property that surprises everyone coming from general-purpose \
bases: there is no shell inside."

section "Step 1 — Pull the image"
say "Each layer streams from the registry into local containers-storage and \
is indexed by digest. Note the size when it lands."
run "podman pull \"$IMG\""
run "podman images \"$HB_REGISTRY/curl\""

section "Step 2 — Inspect the manifest locally (podman + jq)"
say "podman inspect dumps the whole config; jq narrows it to the parts an \
admin cares about — digest, platform, the OCI labels, and the layer count."
watch "a small, single-digit layer count, and vendor/source labels pointing back at Red Hat's pipeline."
run "podman inspect \"$IMG\" | jq '{
  digest: .[0].Digest,
  created: .[0].Created,
  arch: .[0].Architecture,
  os: .[0].Os,
  layers: (.[0].RootFS.Layers | length),
  labels: .[0].Labels
}'"

section "Step 3 — Inspect the SAME manifest WITHOUT pulling (skopeo)"
say "skopeo reads the manifest straight from the registry — no local copy \
needed. This is how you vet an image in a pipeline before you ever pull it."
run "skopeo inspect \"docker://$IMG\" | jq '{
  digest: .Digest,
  os: .Os, arch: .Architecture,
  layers: (.Layers | length),
  labels: .Labels
}'"

section "Step 4 — Content-based layers (podman history)"
say "Hummingbird groups files into layers by the package they belong to \
(via 'chunkah'), not by Containerfile lines. A package update invalidates \
only its own layer, so clients re-pull far less. history shows the split."
run "podman history \"$IMG\""

section "Step 5 — The no-shell moment"
say "The distroless default ships only the application and its direct \
dependencies. No bash, no sh, no coreutils. Try the reflex move — exec a \
shell — and watch it fail by design."
run_fail "podman run --rm -it \"$IMG\" /bin/sh"

say "The image isn't broken — the application IS the entrypoint. For the \
curl image, arguments pass straight through to curl:"
run "podman run --rm \"$IMG\" --version"
run "podman run --rm \"$IMG\" -sS -o /dev/null -w 'HTTP %{http_code} from %{url}\\n' https://example.com"

demo_end "Same tooling you already use; a handful of content-based layers; \
Red Hat provenance in the labels; and an attack surface with no shell to \
land in. Next: when you DO need to look inside, you bring the tools to it."
