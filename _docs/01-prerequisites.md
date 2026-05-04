---
title: Prerequisites
order: 1
description: Install and configure the tooling you'll need before any of the examples will work.
duration: 30 to 45 minutes
---

This page gets your machine ready. Work through it once, in order.
The rest of the tutorial assumes everything here is in place.

There are two parallel tracks below: **Fedora 44** and **macOS**.
Pick whichever matches your machine and skip the other one. A small
number of steps later in the tutorial differ between the two
platforms; those are flagged inline where they appear.

## What you'll have when you finish

The exact version numbers will drift over time — match the major
version, not the patch level.

| Tool             | Purpose                                          | Install via            |
|------------------|--------------------------------------------------|------------------------|
| Podman 5.x       | Run containers rootlessly                        | `dnf` / Podman Desktop |
| Buildah          | Build OCI images without a daemon                | `dnf` / Podman Desktop |
| Skopeo           | Copy and inspect images across registries        | `dnf` / Podman Desktop |
| Podman Compose   | Multi-container apps from a `compose.yaml`       | `dnf` / `pip`          |
| Podman Desktop   | GUI for everything above                         | tarball / Brew Cask    |
| Cosign           | Sign images and attach attestations              | `dnf` / Brew           |
| Syft             | Generate SBOMs from images                       | install script         |
| Grype            | Scan images for CVEs                             | install script         |
| jq               | Parse JSON in shell scripts                      | `dnf` / Brew           |

## Diagram: where these tools sit

{% include excalidraw.html
   file="01-prerequisites-toolchain"
   alt="Diagram showing the relationship between Podman, Buildah, Skopeo, Cosign, Syft, Grype, and the registries they interact with"
   caption="Figure 1.1 — The local toolchain and the registries it talks to" %}

## Track A: Fedora 44

Fedora 44 ships Podman 5.x in the standard repositories, so almost
everything in this section comes from `dnf`. No third-party repos
are required for the core toolchain.

### A.1 — System update and core container tools

```bash
# Refresh metadata and apply updates first. Fedora 44 moves fast and
# you do not want to start the tutorial on stale package state.
sudo dnf update -y --refresh

# The core container toolchain is all in the default repos.
sudo dnf install -y \
  podman \
  buildah \
  skopeo \
  podman-compose \
  podman-plugins \
  containernetworking-plugins \
  netavark \
  aardvark-dns \
  slirp4netns \
  fuse-overlayfs \
  passt \
  jq

# Confirm the versions before continuing.
podman --version
buildah --version
skopeo --version
podman-compose --version
```

Expected: Podman reports 5.x or 6.x, Buildah and Skopeo report a
recent version. If Podman reports 4.x, you are on an older Fedora
release and some commands later in the tutorial will not match —
upgrade the host before continuing.

> **A note on Podman 6.** Fedora 44 ships Podman 5.8.x as of release.
> Podman 6.0 was proposed for Fedora 44 but did not land in time;
> expect it in Fedora 45 or later. The breaking changes that matter
> for this tutorial are the removal of `slirp4netns` (replaced by
> `pasta`, which is already the default) and the removal of the
> BoltDB backend (replaced by SQLite, default since Podman 4.8).
> Neither change affects any command in this tutorial — we use the
> defaults throughout.

### A.2 — Rootless Podman configuration

Fedora 44 enables cgroups v2 and rootless support out of the box,
but a few things still need explicit setup the first time you use
Podman as a non-root user.

```bash
# The installer should have populated subuid/subgid for your user.
# Verify, and only run the usermod commands if either grep is empty.
grep $USER /etc/subuid
grep $USER /etc/subgid

# If either of the above returned nothing:
sudo usermod --add-subuids 100000-165535 $USER
sudo usermod --add-subgids 100000-165535 $USER

# After any change to subuid/subgid, reset Podman's storage so it
# picks up the new ranges. Skip this if subuid/subgid were already
# populated above.
podman system migrate

# Enable user lingering so background services survive logout. This
# matters for compose stacks running in the background later in the
# tutorial.
loginctl enable-linger $USER

# Confirm cgroups v2 is the active hierarchy.
mount | grep cgroup2
# Expected: cgroup2 on /sys/fs/cgroup type cgroup2 ...

# Enable the user-level Podman socket so Podman Desktop and any
# Docker-API clients can talk to it.
systemctl --user enable --now podman.socket

# Confirm the socket is up.
systemctl --user status podman.socket --no-pager | head -5
ls -la $XDG_RUNTIME_DIR/podman/podman.sock
```

### A.3 — Podman Desktop

There are two ways to install Podman Desktop on Fedora. The
recommended path is the upstream tarball, because Flatpak builds
have historically had trouble loading some extensions cleanly.

**Option A — tarball (recommended):**

```bash
# Discover the latest release tag from the project's GitHub API.
# This avoids hard-coding a version that will be stale by the time
# someone else runs through this tutorial.
PDVERSION=$(curl -sSL https://api.github.com/repos/containers/podman-desktop/releases/latest \
  | jq -r '.tag_name')
echo "Installing Podman Desktop ${PDVERSION}"

# Download the Linux tarball for that version.
curl -L -o /tmp/podman-desktop.tar.gz \
  "https://github.com/containers/podman-desktop/releases/download/${PDVERSION}/podman-desktop-${PDVERSION#v}-linux.tar.gz"

# Extract it into a location your user owns.
mkdir -p ~/.local/share/podman-desktop
tar -xzf /tmp/podman-desktop.tar.gz \
  -C ~/.local/share/podman-desktop \
  --strip-components=1

# Add a symlink so `podman-desktop` works from the terminal.
mkdir -p ~/.local/bin
ln -sf ~/.local/share/podman-desktop/podman-desktop ~/.local/bin/podman-desktop

# If ~/.local/bin is not already on PATH, add it.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) echo "PATH already includes ~/.local/bin" ;;
  *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc ;;
esac

# Create a desktop entry so it shows up in your launcher.
cat > ~/.local/share/applications/podman-desktop.desktop <<EOF
[Desktop Entry]
Name=Podman Desktop
Comment=Manage containers with Podman
Exec=$HOME/.local/share/podman-desktop/podman-desktop
Icon=io.podman_desktop.PodmanDesktop
Terminal=false
Type=Application
Categories=Development;
EOF
```

**Option B — Flatpak (if you prefer):**

```bash
flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub io.podman_desktop.PodmanDesktop
```

If you go this route and find an extension fails to install in
section 7 or later, switch to Option A.

### A.4 — Supporting security tools (Cosign, Syft, Grype)

```bash
# Cosign is in the Fedora repos.
sudo dnf install -y cosign
cosign version

# Syft and Grype are not in the Fedora repos. Use the upstream install
# scripts and target ~/.local/bin so we do not need sudo and do not
# pollute /usr/local.
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
  | sh -s -- -b ~/.local/bin
syft --version

curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
  | sh -s -- -b ~/.local/bin
grype --version

# Pre-populate the Grype vulnerability database now, so the first
# scan you run in section 6 is not also waiting on a database
# download.
grype db update
```

### A.5 — Registry credentials

Podman, Buildah, and Skopeo all read credentials from the same file:
`~/.config/containers/auth.json`. Logging in once with `podman login`
populates it for all three tools.

```bash
mkdir -p ~/.config/containers

# Red Hat registry — needed for any UBI builder images we fall back
# to when no Hummingbird builder is available.
podman login registry.access.redhat.com

# Quay.io — where Hummingbird runtime images live.
podman login quay.io

# Confirm what auth.json contains. The output should list the two
# registries above, each with an "auth" entry.
jq '.auths | keys' ~/.config/containers/auth.json
```

If you do not yet have a Red Hat account, create one (free) at
<https://developers.redhat.com>. The registry login uses the same
credentials.

## Track B: macOS

On macOS, Podman runs inside a small virtual machine — a "Podman
machine" — managed by Podman Desktop or by the `podman machine`
CLI. The image-building, image-running, and image-pulling commands
look identical to Fedora; the differences are confined to install
and to the SELinux mount flag (which is harmless on macOS but
matters when you copy commands back to Fedora).

### B.1 — Install Homebrew if you don't already have it

```bash
# Skip this step if `brew --version` already works in your terminal.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Follow the post-install hint Homebrew prints. On Apple Silicon it
# usually tells you to add /opt/homebrew/bin to PATH; on Intel Macs
# it is /usr/local/bin.
brew --version
```

### B.2 — Install Podman Desktop and the CLI tools

```bash
# Podman Desktop pulls in the Podman CLI, Buildah, and Skopeo as
# part of the installation flow. Installing the cask is enough.
brew install --cask podman-desktop

# The supporting tools are separate formulas.
brew install \
  podman-compose \
  cosign \
  syft \
  grype \
  jq

# Confirm versions.
podman --version
buildah --version       # Available once Podman Desktop has set up its VM
skopeo --version
podman-compose --version
cosign version
syft --version
grype --version
```

### B.3 — Create a Podman machine

The first time you launch Podman Desktop it will offer to create a
Podman machine for you. You can also do it from the CLI, which is
the more reproducible path:

```bash
# Initialise a Podman machine. The defaults are reasonable for a
# tutorial workload; bump --memory and --cpus later if you need to.
podman machine init \
  --cpus 4 \
  --memory 8192 \
  --disk-size 50 \
  --rootful=false

# Start it. This is the step that actually boots the VM.
podman machine start

# Confirm Podman can reach the machine. The output should list one
# machine in "running" state.
podman machine list
podman info | head -20
```

> **Why rootless on the VM?** Inside the Podman machine VM,
> containers always run as a Linux process — the rootless flag here
> controls whether they run as the VM's `root` user or as a
> non-root user. We default to non-root so the experience matches
> what we'll do on Fedora 44.

### B.4 — Update the Grype database

```bash
grype db update
```

### B.5 — Registry credentials

Same flow as Fedora; the auth file lives in the same place.

```bash
mkdir -p ~/.config/containers

podman login registry.access.redhat.com
podman login quay.io

jq '.auths | keys' ~/.config/containers/auth.json
```

## Common to both platforms: shared environment

Everything from here down applies to both Fedora 44 and macOS.

### Environment variables you'll reference repeatedly

Add these to your shell profile (`~/.bashrc` on Fedora or `~/.zshrc`
on macOS) so the rest of the tutorial can refer to them by name:

```bash
cat >> "$HOME/.${SHELL##*/}rc" <<'EOF'

# ── Hummingbird tutorial registry shortcuts ──────────────────────────────────
# Override these if you are working against an internal mirror.
export HB_REGISTRY="quay.io/hummingbird"
export RH_REGISTRY="registry.access.redhat.com"

# All container tools read the same auth file.
export REGISTRY_AUTH_FILE="$HOME/.config/containers/auth.json"

# Always build OCI format. Cosign signs OCI; do not silently produce
# Docker-format images.
export BUILDAH_FORMAT="oci"

EOF

# Reload your shell so the variables are live in this session too.
exec $SHELL -l
```

> **What HB_REGISTRY actually points at.** The Hummingbird image
> catalog lives at one Quay.io organization:
> <https://quay.io/organization/hummingbird>. Every image used in
> this tutorial — **both builder and runtime images** — is pulled
> from that organization. The shell variable
> `HB_REGISTRY=quay.io/hummingbird` is the prefix; the rest of the
> path is the image name and tag.
>
> The repository name is just the software (`go`, `python`,
> `openjdk`, `nodejs`, `postgresql`, `nginx`); the **version is in
> the tag**, not in the repository name. So:
>
> - **Builder pull**: `quay.io/hummingbird/<name>:<ver>-builder` —
>   for example `quay.io/hummingbird/python:3.13-builder`.
> - **Runtime pull**: `quay.io/hummingbird/<name>:<ver>` — for
>   example `quay.io/hummingbird/python:3.13`.
>
> Tags exist at three granularities — major (`:3`), major-minor
> (`:3.13`), and full patch (`:3.13.5`). Floating `:latest` and
> `:latest-builder` aliases also exist. A `-fips` suffix is
> available on every variant if your environment requires
> FIPS-validated cryptography (`python:3.13-fips-builder`,
> `python:3.13-fips`, etc.); the tutorial doesn't use FIPS by
> default but every example would work with the suffix added.
>
> OpenJDK has one extra wrinkle worth knowing: there's a JDK/JRE
> split. `openjdk:21` is the full JDK; `openjdk:21-runtime` is
> JRE-only and meaningfully smaller as a runtime image. Build
> with `openjdk:21-builder`, deploy on `openjdk:21-runtime`.
>
> Red Hat customers can also use `registry.access.redhat.com/hi/<name>:<tag>`
> — the same images via the Red Hat container catalog. The two
> paths should resolve to the same content. The tutorial uses
> `quay.io/hummingbird` as the default because it works without a
> Red Hat subscription; if you want the customer path, override
> with `HB_REGISTRY=registry.access.redhat.com/hi`.
>
> The source material for this tutorial referenced
> `quay.io/hummingbird-hatchling` (the early-access organization,
> "hatchling" meaning pre-GA). If you're working against the
> early-access org rather than the GA one, set
> `HB_REGISTRY=quay.io/hummingbird-hatchling` and the rest of the
> examples will adapt automatically.

### Smoke test

Run this end-to-end check. If anything errors, jump back to the
relevant subsection above before moving on to section 2.

```bash
echo "=== Tool versions ==="
podman --version
buildah --version  || echo "buildah missing"
skopeo --version   || echo "skopeo missing"
cosign version     || echo "cosign missing"
syft --version     || echo "syft missing"
grype --version    || echo "grype missing"
jq --version       || echo "jq missing"

echo
echo "=== Registry auth ==="
jq '.auths | keys' "$REGISTRY_AUTH_FILE"

echo
echo "=== Rootless smoke test ==="
podman run --rm "$RH_REGISTRY/ubi9/ubi9-micro:latest" \
  echo "Rootless container exited cleanly"
```

If the rootless smoke test prints `Rootless container exited
cleanly` and the version checks all show numbers, you are ready
for section 2.

## Where to go next

You're now ready to work through
[What is Project Hummingbird]({{ "/docs/02-introduction/" | prepend: site.baseurl }}),
which gives you the conceptual grounding before we start running
Hummingbird-specific commands in section 3.
