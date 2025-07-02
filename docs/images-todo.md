# Jupyter Notebook Docker Images: Lightweight Options for VPS

This guide summarizes the best small Docker images for running Jupyter Notebook on a VPS, with practical setup instructions and tips for persistent storage.

---

## ⭐ Best Small Images

- **jupyter/minimal-notebook**: Official, small, and ideal for basic Jupyter Notebook features. Great for testing and lightweight deployments.
- **jusher/jupyterlab-minimalist**: Custom image (~873MB) with Python, JupyterLab, NumPy, Pandas, Matplotlib, and scikit-learn. Much smaller than standard images and follows Docker best practices.
- **DbGate**: Yes (Docker support), Yes (lightweight), supports MySQL, PostgreSQL, SQL Server, SQLite, MongoDB, CockroachDB. Features spreadsheet-like editing, open source, and easy Docker deployment.

---

## 🚀 Recommended Setup

Start with the official minimal image for best support and essential features:

```bash
# Pull the minimal image
docker pull jupyter/minimal-notebook:latest

# Run with port mapping
docker run -p 8888:8888 jupyter/minimal-notebook:latest
```

---

## 🐧 Docker Distribution & Base Image

- Official Jupyter images use **Ubuntu** for better compatibility with scientific packages.
- For extreme minimalism, you can build your own image based on Alpine, but this may require extra work for package compatibility.

---

## 🏗️ Alternative: Custom Minimalist Image

For maximum control and minimal size:
- ~30 line Dockerfile, easy to extend
- Multi-stage builds for efficiency
- Based on the official Python image

```bash
docker pull jusher/jupyterlab-minimalist:latest
docker run -it -p 8888:8888 jusher/jupyterlab-minimalist:latest
```

---

## 📂 Persistent Storage

To keep your notebooks and data across container restarts, mount a local directory as a volume:

```bash
docker run -p 8888:8888 -v /path/to/your/notebooks:/home/jovyan/work jupyter/minimal-notebook:latest
```

---

## 🔑 Accessing Jupyter Notebook

After starting the container, Docker will print a URL with a security token. Copy this URL into your browser to access Jupyter Notebook on your VPS.

---

## 📚 References

- [Jupyter on Docker (dev.to)](https://dev.to/akilesh/jupyter-on-docker-8mm)
- [Jupyter on Docker (ops.io)](https://community.ops.io/akilesh/jupyter-on-docker-37gk)
- [jusher/jupyterlab-minimalist (GitHub)](https://github.com/gitjeff05/jupyterlab-minimalist-image)
- [Selecting a Jupyter Docker Stack](https://jupyter-docker-stacks.readthedocs.io/en/latest/using/selecting.html)
- [Jupyter Docker Stacks (Docs)](https://jupyter-docker-stacks.readthedocs.io)
- [Minimal Notebook (Docker Hub)](https://hub.docker.com/r/jupyter/minimal-notebook/)
- [How to run Jupyter in Docker (Deepnote)](https://deepnote.com/guides/jupyter/how-to-run-jupyter-in-docker)
