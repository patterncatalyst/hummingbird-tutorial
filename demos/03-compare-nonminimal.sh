#!/usr/bin/env bash
# Demo 3 — Minimal vs non-minimal: size, layer count, and contents.
#          size, layer count, and what actually lives in the filesystem.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib/_demo.sh"

demo_title 3 "Minimal vs non-minimal — size, layers, and what's inside"
require_tools podman skopeo jq || exit 0

HB="$HB_REGISTRY/nginx:1"
FAT="$FAT_IMAGE"   # docker.io/library/nginx:latest

demo_intro "Same software — nginx — two very different images. One is the \
hardened, distroless Hummingbird build; the other is a stock general-purpose \
nginx with a full OS underneath. We'll put their size, layer count, and \
contents side by side so the 'minimal' claim has numbers behind it."

section "Step 1 — Make sure both images are present"
run "podman pull \"$HB\""
run "podman pull \"$FAT\""

section "Step 2 — Size, side by side"
say "The hardened image carries only nginx and its direct dependencies. The \
general-purpose image carries a whole userland it will probably never use."
run "podman images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E 'nginx' | grep -Ev 'NONE'"

section "Step 3 — Layer count — and why the hardened image has MORE"
say "Counter-intuitive: the hardened image usually has MANY more layers than \
the general-purpose one. That isn't bloat — it's chunkah, content-based \
layer splitting. Hummingbird groups files into roughly one layer per \
package instead of one per Containerfile line, so a single package update \
invalidates only its own layer and clients re-pull just that slice."
run "printf 'hardened  : '; skopeo inspect \"docker://$HB\"  | jq '.Layers | length'"
run "printf 'stock     : '; skopeo inspect \"docker://$FAT\" | jq '.Layers | length'"
watch "the hardened image with the HIGHER count. Layer count is a packaging choice, not a size or attack-surface measure — size (step 2) and contents (step 4) are the real signals; package and CVE counts come in demos 5 and 6."

section "Step 4 — What's actually inside?"
say "This is the part that lands with admins. The hardened image has no shell \
to even run an inventory in — that absence IS the result. The stock image \
has hundreds of executables, a full package database, and a package manager."
run_fail "podman run --rm \"$HB\" /bin/sh -c 'ls /bin | wc -l'"
say "Now the same questions against the general-purpose image, which happily \
answers them because it ships a complete OS:"
run "podman run --rm \"$FAT\" sh -c 'echo \"OS:        \$(. /etc/os-release; echo \$PRETTY_NAME)\"; \
            echo \"binaries:  \$(ls /bin /usr/bin 2>/dev/null | sort -u | wc -l)\"; \
            echo \"dpkg pkgs: \$(dpkg -l 2>/dev/null | grep -c ^ii)\"; \
            echo \"has bash:  \$(command -v bash || echo no)\"; \
            echo \"has apt:   \$(command -v apt-get || echo no)\"'"

section "Step 5 — The takeaway in one line"
say "Every binary, library, and package in the stock image is attack surface \
you now own and must patch. The hardened image removed the question by \
removing the contents. Demo 6 turns this contents gap into a CVE count."

demo_end "Same app, a fraction of the size, more (content-based) layers by \
design, and nothing in the image you didn't ask for. Next: how you build \
YOUR app on top of these images with a multi-stage build."
