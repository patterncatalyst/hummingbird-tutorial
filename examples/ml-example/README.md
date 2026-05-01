# ml-example

FastAPI service with a NumPy dependency, demonstrating the wheel-build
multi-stage pattern when the runtime needs scientific Python libraries
that compile native code. Walked through in
[§11 — Real-world examples (Scenario 2)](../../_docs/11-real-world-examples.md).

The default `requirements.txt` is deliberately light (just NumPy) so
the build finishes in a reasonable time for a tutorial. Uncomment the
`transformers` and `torch` lines if you want a real ML build — they
work but they take much longer.

## Build and run

```bash
cd $(git rev-parse --show-toplevel)/examples/ml-example

podman build -t hb-ml-example:latest .

podman run -d --name hb-ml -p 8000:8000 hb-ml-example:latest
sleep 3
curl -s http://localhost:8000 | jq
# {"status":"ok","matrix_sum":3.0}

podman stop hb-ml && podman rm hb-ml
```

## Why this isn't just `python-example`

The tutorial structure separates the two so each can be linked from a
different scenario. The Containerfiles are nearly identical — the only
substantive difference is what's in `requirements.txt`. That is the
point: once you know the wheel-build pattern, swapping in a different
dependency set is the entire change.

If you want to compare image sizes:

```bash
podman build -t hb-py-baseline ../python-example
podman build -t hb-ml-example .
podman images | grep -E 'hb-(py-baseline|ml-example)'
```

The ML image will be larger because NumPy ships substantial native
code; that's a real cost, not waste — but worth knowing about before
adding ML dependencies casually.

## Image-name caveat

Same as `python-example`. See the
[reconciliation plan](../../plans/reconciliation-plan.md) §A.
