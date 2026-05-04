---
title: Pruning Podman images and build cache
order: 16
description: Reclaim disk on a laptop where Hummingbird base updates accumulate. Covers podman image prune, podman system prune, --filter expressions, buildah unshare, and scheduled cleanup.
duration: 15 minutes
---

This section is short, practical, and runs once when you notice
your laptop's disk is full and never again until it is again.
Working through the rest of the tutorial — pulling Hummingbird
runtimes and builders for several languages, building three or
four examples, running CVE scans that pull more layers — racks
up dozens of gigabytes of containers-storage. Most of it is
recoverable.

## See where the space went

Two commands. `podman system df` summarises by category;
`podman images` lists individually so you can spot the heavy
hitters:

```bash
# Headline numbers. Look at the SIZE and RECLAIMABLE columns.
podman system df

# Per-image breakdown, sorted big-to-small.
podman images --format '{% raw %}{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}{% endraw %}' \
  | sort -k2 -h -r | head -20
```

A typical mid-tutorial state on Fedora 44:

```
TYPE            TOTAL  ACTIVE  SIZE     RECLAIMABLE
Images          47     6       12.3 GB  9.8 GB (79%)
Containers      8      2       412 MB   396 MB (96%)
Local Volumes   3      1       180 MB   140 MB (77%)
Build Cache     0      0       0 B      0 B
```

That `RECLAIMABLE` column is the one to watch — 9.8 GB sitting
unused.

## Three pruning verbs

Pick one based on how aggressive you want to be:

### `podman image prune` — dangling only

Removes images that no tag points at — typically intermediate
build layers and replaced bases. Safe to run; won't touch any
image you've explicitly pulled or built.

```bash
podman image prune
# Will be prompted: "Are you sure...?". Add -f to skip.
```

### `podman image prune -a` — everything unused

Removes any image with no running container. This includes
images you pulled but haven't run lately. Aggressive but
predictable; the next `podman build` will re-pull what it
needs.

```bash
podman image prune -af
```

After this, `podman images` is much shorter, and `podman build`
on your existing Containerfiles will repopulate exactly what
those Containerfiles reference.

### `podman system prune` — everything unused, full sweep

Images, containers, networks, build cache — all of the above,
in one command. The "I want a clean slate" option:

```bash
podman system prune -af --volumes
```

`--volumes` extends the sweep to unused named volumes. Without
it, volumes are preserved, which is usually what you want
(databases, persistent state).

## Pruning by age — keep recent, remove old

The blunt prunes above don't distinguish "pulled yesterday"
from "pulled three months ago". You can keep the recent stuff:

```bash
# Remove unused images older than 30 days.
podman image prune -af --filter "until=720h"

# Remove unused containers older than 7 days.
podman container prune -f --filter "until=168h"
```

`until` takes a Go duration string — `168h` is a week, `720h`
is 30 days, `2160h` is 90 days. There's no `30d` shorthand.

For finer control, prune by image label:

```bash
# Remove only images you tagged as "experimental".
podman image prune -af --filter "label=stage=experimental"
```

This works well when your build pipeline tags throwaway images
distinctly from canonical ones.

## The build cache (Buildah)

`podman build` and `buildah bud` use a shared build cache. When
you build the same Containerfile repeatedly, the cache is what
makes the second build fast. It also accumulates indefinitely:

```bash
# How much is in there?
podman system df --format json | jq '.BuildCache'

# Clear all cache entries.
buildah prune --all

# Or clear cache older than a week.
buildah prune --filter "unused-for=168h"
```

If you suspect a build is using stale cache (an apparently-fixed
bug doesn't go away), `buildah prune --all` followed by `podman
build --no-cache` is the diagnostic.

## Rootless quirk: when prune doesn't seem to free space

In rootless mode, container layers live under
`~/.local/share/containers/storage`. After a prune,
**`du -sh` may still show the old total** until the storage
backend (overlay or fuse-overlayfs) actually releases the
unlinked content. To force release:

```bash
buildah unshare rm -rf ~/.local/share/containers/storage/overlay-layers/*-staging
```

Use sparingly; that's a sledgehammer. Most of the time waiting
30 seconds is enough.

If the storage backend's bookkeeping has truly drifted from
reality (extremely rare), the nuclear option is:

```bash
podman system reset
# Confirms before doing anything destructive. This wipes
# everything containers-storage knows about — images,
# containers, volumes. You'll re-pull bases on next use.
```

## Scheduled cleanup

If you live on this laptop, set up a weekly prune so it never
gets bad. A systemd user timer is the right shape on Fedora; on
macOS a `launchd` plist or a `cron` entry works.

### Fedora — systemd user units

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/podman-prune.service <<'EOF'
[Unit]
Description=Weekly podman image prune

[Service]
Type=oneshot
ExecStart=/usr/bin/podman image prune -af --filter until=336h
ExecStart=/usr/bin/buildah prune --filter unused-for=336h --all
EOF

cat > ~/.config/systemd/user/podman-prune.timer <<'EOF'
[Unit]
Description=Weekly podman image prune

[Timer]
OnCalendar=Sun 03:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now podman-prune.timer

# Confirm it's scheduled.
systemctl --user list-timers podman-prune.timer
```

`until=336h` = 14 days. The timer runs every Sunday at 3am;
anything older than two weeks gets pruned. `Persistent=true`
means a missed run (laptop was asleep) catches up next time
the timer activates.

### macOS — launchd

```bash
cat > ~/Library/LaunchAgents/com.user.podman-prune.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.user.podman-prune</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/podman</string>
    <string>image</string>
    <string>prune</string>
    <string>-af</string>
    <string>--filter</string>
    <string>until=336h</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>0</integer>
    <key>Hour</key><integer>3</integer>
  </dict>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.user.podman-prune.plist
```

The path may be `/opt/homebrew/bin/podman` (Apple Silicon) or
`/usr/local/bin/podman` (Intel) — adjust based on `which podman`.

## Verifying the freed space

After any prune, re-run `podman system df`:

```bash
podman system df
```

The `RECLAIMABLE` column should be near zero. If it isn't, you
likely have running containers holding references — `podman
ps -a` will show them.

A practical pattern after a tutorial-running session:

```bash
# Stop and remove tutorial containers.
podman ps -aq | xargs -r podman rm -f

# Prune unused images.
podman image prune -af

# Confirm.
podman system df
```

That sequence reliably brings my Fedora laptop back from "full"
to "20–30% used".

## Verify before moving on

You should be able to:

- read `podman system df` and identify how much storage is
  reclaimable,
- choose between `podman image prune`, `podman image prune -a`,
  and `podman system prune` for a stated goal,
- prune by age using `--filter until=...`,
- explain when `buildah unshare` is needed,
- set up a weekly automated prune via systemd or launchd.

## Where to go next

You've now seen the full tutorial. The
[reconciliation plan]({{ "/plans/reconciliation-plan/" | prepend: site.baseurl }})
records what's still being verified end-to-end against a live
Hummingbird catalog. The
[examples directory]({{ "/examples/" | prepend: site.baseurl }})
has every Containerfile from the tutorial as a runnable
companion project.

Working backwards through the section list: when something
breaks in production, return to
[Debugging Hummingbird containers]({{ "/docs/08-debugging/" | prepend: site.baseurl }})
and the four-layer model. When CI starts pulling unexpected
images, return to
[Automated updates with Renovate]({{ "/docs/15-renovate/" | prepend: site.baseurl }})
and check the regex manager. When base updates pile up on your
laptop, you're back here. The tutorial is built so the sections
make sense to revisit individually.
