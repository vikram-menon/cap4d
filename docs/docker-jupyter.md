# Docker Jupyter Workflow

This repo can be run from a Docker container with JupyterLab exposed on `localhost:8888`.

## Start

```bash
docker compose build
docker compose up
```

Open:

```text
http://localhost:8888/lab?token=cap4d
```

You can change the token and host port:

```bash
JUPYTER_TOKEN=mytoken JUPYTER_PORT=8890 docker compose up
```

## What you get

- JupyterLab in the browser
- notebook execution
- Jupyter terminals for shell commands
- repo mounted live from your local checkout
- persistent runtime data in the `cap4d_runtime` Docker volume

## Notes

- The CAP4D pipeline is GPU-oriented. The container is configured for NVIDIA GPU access.
- The notebook `notebooks/changed_colab_static_avatar.ipynb` will use the mounted repo inside the container instead of recloning it.
- FLAME credentials are still required for the download/install steps.
