"""Companion FastAPI app for §4 of the Hummingbird tutorial."""
import sys

from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def root():
    """Return a small JSON document so the example can be smoke-tested."""
    return {
        "status": "ok",
        "runtime": "hummingbird-python",
        "python": sys.version.split()[0],
    }
