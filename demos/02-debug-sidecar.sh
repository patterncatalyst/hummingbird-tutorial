#!/usr/bin/env bash
# Demo 2 — Ephemeral debug sidecar: a toolbox for a shell-less container.
#          container by sharing its PID and network namespaces.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib/_demo.sh"

demo_title 2 "Ephemeral debug sidecar — a toolbox for a shell-less container"
require_tools podman || exit 0

NGINX="$HB_REGISTRY/nginx:1"
TOOLBOX="$RH_REGISTRY/ubi9/toolbox:latest"
CTR="hbdemo-nginx"
PORT=18190
track "$CTR"

demo_intro "If there's no shell in the image, how do you debug a running \
container? You don't get into it — you put a SECOND container alongside it \
that shares its namespaces. The production container stays untouched; the \
toolbox brings bash, ps, ss, curl, strace and friends. Let's run a hardened \
nginx, fail to exec into it, then attach a toolbox sidecar that can see \
straight into it."

section "Step 1 — Run a hardened nginx in the background"
run "podman run -d --name $CTR -p $PORT:8080 \"$NGINX\""
run "podman ps --filter name=$CTR"
run "curl -sI http://127.0.0.1:$PORT | head -1"

section "Step 2 — The reflex move fails (no shell)"
say "Muscle memory says 'exec in and look around'. That habit ends here."
run_fail "podman exec -it $CTR /bin/sh"

section "Step 3 — Attach an ephemeral toolbox sidecar"
say "A throwaway UBI toolbox that shares the nginx container's PID and \
network namespaces. Because they share PID space, the toolbox's ps sees \
nginx's processes; because they share the network, 'localhost' inside the \
toolbox IS nginx's localhost. --rm means it vanishes when we're done."
watch "nginx worker processes, a listener on :8080, and a 200 over the shared loopback — all from a separate container."
run "podman run --rm \
  --pid=container:$CTR \
  --network=container:$CTR \
  \"$TOOLBOX\" \
  bash -lc 'echo \"== processes (shared PID ns) ==\"; ps -ef | grep -i nginx | grep -v grep; \
            echo; echo \"== listeners (shared net ns) ==\"; ss -tlnp; \
            echo; echo \"== reach it over shared localhost ==\"; curl -sI http://localhost:8080 | head -1'"

section "Step 4 — When you need ptrace (strace / gdb)"
say "The basic sidecar covers most cases. For strace/gdb you must add the \
SYS_PTRACE capability and, on SELinux-enforcing Fedora, relax the label for \
the debug container only — the target's labels are unchanged. Shown here, \
not run, because it lifts a security constraint:"
note "podman run --rm -it --cap-add=SYS_PTRACE --security-opt label=disable \\"
printf '%b\n' "       ${YELLOW}  --pid=container:$CTR --network=container:$CTR --user 0 \\\\${NC}"
printf '%b\n' "       ${YELLOW}  $TOOLBOX bash   # then: dnf install -y strace; strace -p 1${NC}"

section "Step 5 — Optional: drop into a live toolbox yourself"
say "Want to poke around for real? This opens an interactive toolbox shell \
sharing the nginx container. Try 'ps -ef', 'ss -tlnp', 'curl -v \
http://localhost:8080', 'ls -la /proc/1/fd', then 'exit' to come back."
if [[ -z "$DEMO_NO_PAUSE" ]]; then
    printf '%b' "  ${BOLD}Open an interactive toolbox now? [y/N] ${NC}"
    IFS= read -r ans </dev/tty 2>/dev/null || ans=""
    if [[ "$ans" == [yY]* ]]; then
        run "podman run --rm -it --pid=container:$CTR --network=container:$CTR \"$TOOLBOX\" bash"
    else
        note "Skipped the live shell."
    fi
fi

demo_end "The container under test never changed — we added a disposable \
toolbox beside it and threw it away. That's the distroless debugging story: \
diagnostics live in a sidecar, not in your production image."
