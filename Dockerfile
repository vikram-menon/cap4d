FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /workspace/cap4d

RUN apt-get update && apt-get install -y \
    bash \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    ffmpeg \
    git \
    libgl1 \
    libglib2.0-0 \
    ninja-build \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/local/bin/python && \
    ln -sf /usr/bin/pip3 /usr/local/bin/pip

COPY requirements.txt /tmp/requirements.txt

RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install \
      torch==2.5.1 \
      torchvision==0.20.1 \
      --index-url https://download.pytorch.org/whl/cu121 && \
    grep -v -E '^(torch|torchvision)$' /tmp/requirements.txt > /tmp/requirements.filtered.txt && \
    python -m pip install -r /tmp/requirements.filtered.txt && \
    python -m pip install \
      jupyterlab \
      ipykernel \
      notebook && \
    FORCE_CUDA=1 python -m pip install "git+https://github.com/facebookresearch/pytorch3d.git@stable"

COPY docker/jupyter/start-notebook.sh /usr/local/bin/start-notebook.sh
RUN chmod +x /usr/local/bin/start-notebook.sh && mkdir -p /workspace/runtime

EXPOSE 8888

CMD ["/usr/local/bin/start-notebook.sh"]
