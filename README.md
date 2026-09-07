# Simple HTML Calculator with Kubernetes (Minikube)

A learning project that hosts a **simple calculator** (addition & subtraction only) with **Apache (`httpd:alpine`)**, packages it as a Docker image, and runs it on **Minikube** with a **3-replica Deployment** behind a **NodePort Service**.

Each pod injects its **Kubernetes pod name** into the page at startup so you can see which replica served the request.

---

## Preview (local Docker)

Local container on port **7070**:

![Simple calculator v1 — localhost:7070](reference/local-docker-build-calculator-v1.png)

---

## Table of contents

1. [Overview](#overview)
2. [Project structure](#project-structure)
3. [How the app works](#how-the-app-works)
4. [Prerequisites](#prerequisites)
5. [Run locally with Docker](#run-locally-with-docker)
6. [Push image to Docker Hub](#push-image-to-docker-hub)
7. [Deploy on Minikube](#deploy-on-minikube)
8. [Which pod serves the UI?](#which-pod-serves-the-ui)
9. [Image updates (`imagePullPolicy`)](#image-updates-imagepullpolicy)
10. [Useful kubectl commands](#useful-kubectl-commands)
11. [Troubleshooting](#troubleshooting)
12. [Setup cheat sheet](#setup-cheat-sheet)

---

## Overview

| Layer | Purpose |
|--------|---------|
| `index.html` | Calculator UI (+ / − only) + “Served by pod” display |
| `Dockerfile` | `httpd:alpine` + inject pod hostname at container start |
| `simplecasio_deployment.yaml` | Deployment (3 replicas) + NodePort Service |
| `Setup_Cheat_Sheet.info` | Quick command notes used during setup |
| `JenkinsFile` | Older pipeline sample (still points at a previous repo; update before use) |

**Example values used in this project**

| Item | Example |
|------|---------|
| Local image | `simplecasioimg:1.0` |
| Docker Hub image | `dockermano1984/simplecasioimg:1.1` |
| Local run port | `7070` → container `80` |
| K8s replicas | `3` |
| Service type | `NodePort` |
| NodePort | `30060` |
| Service name | `simplecasiopod-service` |
| Deployment name | `simplecasio-deployment` |

---

## Project structure

```text
.
├── index.html                      # Calculator UI
├── Dockerfile                      # httpd:alpine + hostname injection
├── simplecasio_deployment.yaml     # Deployment + Service
├── Setup_Cheat_Sheet.info          # Command notes
├── JenkinsFile                     # Pipeline sample (update for this repo)
├── README.md
└── reference/
    └── local-docker-build-calculator-v1.png
```

---

## How the app works

### Calculator

- Static HTML/CSS/JS served by Apache
- Supports **addition** and **subtraction** only
- Buttons + keyboard (`+`, `-`, Enter, Backspace, Escape)

### Pod name on the page

The HTML contains a placeholder `__POD_HOSTNAME__`.  
The Dockerfile `ENTRYPOINT` replaces it with `$HOSTNAME` when the container starts:

- **In Kubernetes**, `HOSTNAME` is usually the **pod name**
- Refresh a few times via the Service — you may see different pod names

This proves that traffic is **load-balanced across replicas**, not locked to one pod forever.

---

## Prerequisites

- Docker Desktop (Windows)
- Minikube
- `kubectl`
- (Optional) Docker Hub account to push/pull images

---

## Run locally with Docker

From the project root:

```powershell
cd F:\learning\OneDrive\Documents\2026\simplehtmlcalcwithk8s

docker build -t simplecasioimg:1.0 .

docker run -d -p 7070:80 --name simplecasiocntr simplecasioimg:1.0
```

Open: [http://localhost:7070/](http://localhost:7070/)

Stop and remove:

```powershell
docker rm -f simplecasiocntr
```

### Port mapping reminder

```text
-p HOST:CONTAINER
-p 7070:80   → open http://localhost:7070/
```

Use the **left** (host) port in the browser URL.  
Some browsers block special ports (for example **143** / IMAP). Prefer ports like `7070`, `8080`, `1430`.

---

## Push image to Docker Hub

```powershell
docker login

docker tag simplecasioimg:1.0 dockermano1984/simplecasioimg:1.1
docker push dockermano1984/simplecasioimg:1.1
```

Update `simplecasio_deployment.yaml` `image:` to match the tag you pushed.

---

## Deploy on Minikube

### 1. Start cluster

```powershell
minikube start --kubernetes-version=v1.32.0 --cpus=2 --memory=4000
kubectl get nodes
```

### 2. Make the image available to Minikube

Docker Desktop and Minikube do **not** share images automatically.

**Option A — load local/Hub-tagged image into Minikube**

```powershell
minikube image load dockermano1984/simplecasioimg:1.1
```

**Option B — push to Docker Hub** and let the cluster pull (with `imagePullPolicy: Always`)

### 3. Apply manifests

```powershell
kubectl apply -f .\simplecasio_deployment.yaml
kubectl get deploy,rs,pods,svc
```

### 4. Open the app

```powershell
minikube service simplecasiopod-service --url
```

On Windows with the Docker driver, keep that terminal open while you browse the printed URL.

You can also use NodePort `30060` via Minikube’s node IP (depending on driver/setup).

### 5. Clean up deployment (optional)

```powershell
kubectl delete deploy simplecasio-deployment
```

(The Service can remain, or delete it separately if needed.)

---

## Which pod serves the UI?

With **3 replicas**, the Service load-balances to **any Ready pod**.  
There is no permanent “one pod only” for all requests.

Check eligible backends:

```powershell
kubectl get endpoints simplecasiopod-service
kubectl get pods -l app=simplecasio_lbl -o wide
```

On the web page, use the **Served by pod** box and refresh several times.

---

## Image updates (`imagePullPolicy`)

Place this next to `image:` in the Deployment container spec:

```yaml
image: dockermano1984/simplecasioimg:1.1
imagePullPolicy: Always
```

| Value | Behavior |
|--------|----------|
| `Always` | Always try to pull before start |
| `IfNotPresent` | Pull only if missing on the node |
| `Never` | Never pull; image must already exist on the node |

**Defaults if omitted**

| Image tag | Default policy |
|-----------|----------------|
| `:latest` or no tag | `Always` |
| Other tags (`:1.0`, `:1.1`) | `IfNotPresent` |

Rebuilding and keeping the **same tag** often keeps the **old cached image** on Minikube. Prefer:

1. New tag (`1.1`, `1.2`, …), **or**
2. `imagePullPolicy: Always` + push/load + restart pods

```powershell
docker build -t dockermano1984/simplecasioimg:1.1 .
docker push dockermano1984/simplecasioimg:1.1
minikube image load dockermano1984/simplecasioimg:1.1
kubectl rollout restart deploy simplecasio-deployment
```

Hard-refresh the browser (`Ctrl+F5`) after deploy.

---

## Useful kubectl commands

```powershell
kubectl get nodes
kubectl get ns
kubectl get pods -o wide
kubectl get pods -A
kubectl get rs
kubectl get deploy
kubectl get svc
kubectl get endpoints
kubectl get all

kubectl describe deploy simplecasio-deployment
kubectl logs -l app=simplecasio_lbl --prefix=true
kubectl rollout restart deploy simplecasio-deployment
kubectl rollout status deploy/simplecasio-deployment
```

---

## Troubleshooting

### Browser: port works in `docker ps` but page won’t open

- Confirm URL uses the **host** port from `-p HOST:80`
- Avoid browser-blocked ports (e.g. `143`)
- Test with: `curl http://127.0.0.1:<host-port>/`

### K8s still shows old HTML after rebuild

- Same tag + `IfNotPresent` → node cache reused
- Image built in Docker Desktop but not loaded/pulled into Minikube
- Browser cache — use `Ctrl+F5`
- Verify inside a pod:

```powershell
kubectl exec deploy/simplecasio-deployment -- cat /usr/local/apache2/htdocs/index.html | findstr /i "Served by pod POD_HOSTNAME"
```

### `minikube service ... --url` stops working

With Docker driver on Windows, the tunnel needs the terminal left open.

### `kubectl apply` says Service `unchanged` but Deployment `configured`

`configured` only means a non-empty patch was applied (often annotations/defaults). It does **not** always mean pods rolled out. Check ReplicaSet age / `kubectl rollout status`.

---

## Setup cheat sheet

Condensed from [`Setup_Cheat_Sheet.info`](Setup_Cheat_Sheet.info):

1. Start Docker Desktop  
2. Build calculator HTML (add / subtract only)  
3. Dockerfile with `httpd:alpine` + `index.html`  
4. `docker build -t simplecasioimg:1.0 .`  
5. `docker run -d -p 7070:80 --name simplecasiocntr simplecasioimg:1.0`  
6. Open http://localhost:7070/  
7. `minikube start --kubernetes-version=v1.32.0 --cpus=2 --memory=4000`  
8. `kubectl apply -f .\simplecasio_deployment.yaml`  
9. `minikube service simplecasiopod-service --url`  
10. For image refresh: push/load + `kubectl rollout restart deploy simplecasio-deployment`

---

## Quick reference

```powershell
# Local Docker
docker build -t simplecasioimg:1.0 .
docker run -d -p 7070:80 --name simplecasiocntr simplecasioimg:1.0

# Hub
docker tag simplecasioimg:1.0 dockermano1984/simplecasioimg:1.1
docker push dockermano1984/simplecasioimg:1.1

# Minikube
minikube start --kubernetes-version=v1.32.0 --cpus=2 --memory=4000
minikube image load dockermano1984/simplecasioimg:1.1
kubectl apply -f .\simplecasio_deployment.yaml
minikube service simplecasiopod-service --url
```

---

## Purpose

Learning demo for:

- Static web app in Docker (`httpd`)
- Docker Hub publish/pull
- Minikube Deployments, ReplicaSets, Services
- Multi-replica load balancing and identifying the serving pod
