from fastapi import FastAPI
import numpy as np

app = FastAPI()


@app.get("/")
def root():
    # Trivial NumPy operation to confirm the dependency loaded.
    return {
        "status": "ok",
        "matrix_sum": float(np.eye(3).sum()),
    }
