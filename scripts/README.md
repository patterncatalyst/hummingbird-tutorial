# scripts/

Helper scripts for the tutorial. Two kinds of things live here.

## Example test scripts

Each `test-<example>.sh` builds, runs, and validates one of the runnable
examples in `examples/`. They use `127.0.0.1` explicitly (avoiding the
IPv4/IPv6 dual-stack pitfall described in §17), tear down their
containers cleanly even on failure, and exit non-zero on any problem.

| Script                    | Tests                              | Port  |
|---------------------------|------------------------------------|-------|
| `test-quarkus.sh`         | examples/quarkus-example           | 18080 |
| `test-python.sh`          | examples/python-example            | 18081 |
| `test-go.sh`              | examples/go-example                | 18082 |
| `test-node.sh`            | examples/node-example              | 18083 |
| `test-ml.sh`              | examples/ml-example                | 18084 |
| `test-compose-stack.sh`   | examples/compose-stack             | 3000  |
| `test-all-examples.sh`    | All of the above, in sequence      | —     |

Run any of them from anywhere — they auto-detect the repo root:

```bash
bash scripts/test-go.sh                # one example
bash scripts/test-all-examples.sh      # all of them
```

The aggregator does **not** fail fast — every test runs regardless of
earlier results, then a final summary tallies pass/fail. Useful when
you want to see all problems at once after a refactor rather than
fixing them one re-run at a time.

The `lib/_helpers.sh` is sourced by each test for color output, the
repo-root finder, and the `wait_for_http` helper. Don't run it
directly.

## Workflow scripts

`secure-build.sh` is the local DevSecOps pipeline from
[§11 Real-world examples](../_docs/11-real-world-examples.md), Scenario 4
— builds, scans, signs, and pushes a Hummingbird-based image with a
hard fail if any high-severity CVE is found. See the §11 walkthrough
for usage.
