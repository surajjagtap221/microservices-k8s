# 🚀 Kubernetes Microservice: Flask & MongoDB Application

A modern, containerized Flask microservice backed by MongoDB, deployed on Kubernetes. This application showcases production-grade containerization, persistent storage volume mapping, internal service routing, and deployment readiness on modern cloud platforms like **AWS EC2**.

---

## 📋 Table of Contents
- [✨ Key Features](#-key-features)
- [🛠 Tech Stack & Modernizations](#-tech-stack--modernizations)
- [📐 Microservice Connection Architecture](#-microservice-connection-architecture)
- [📦 Local Development (Docker)](#-local-development-docker)
- [☁️ AWS EC2 & Kubernetes Deployment Guide](#%EF%B8%8F-aws-ec2--kubernetes-deployment-guide)
  - [1. Launch & Configure EC2 Instance](#1-launch--configure-ec2-instance)
  - [2. Install Kubernetes (K3s)](#2-install-kubernetes-k3s)
  - [3. Set Up Persistent Host Storage](#3-set-up-persistent-host-storage)
  - [4. Build & Push Your Custom Docker Image](#4-build--push-your-custom-docker-image)
  - [5. Deploy Microservices to Kubernetes](#5-deploy-microservices-to-kubernetes)
- [🔌 API Endpoint Reference](#-api-endpoint-reference)
- [🚨 Advanced Troubleshooting Guide](#-advanced-troubleshooting-guide)
  - [1. Exit Code 139: MongoDB Segmentation Fault (SIGSEGV)](#1-exit-code-139-mongodb-segmentation-fault-sigsegv)
  - [2. Exit Code 62: Wrong mongod Version (FCV Mismatch)](#2-exit-code-62-wrong-mongod-version-fcv-mismatch)
  - [3. Strict Decoding Error (YAML Indentation Error)](#3-strict-decoding-error-yaml-indentation-error)

---

## ✨ Key Features
- **Modern REST API**: Clean RESTful endpoints implementing full CRUD operations on tasks.
- **Persistent Database State**: Integrated with MongoDB using Kubernetes PersistentVolumes (`PV`) and Claims (`PVC`) to guarantee data preservation across pod rescheduling or failures.
- **Robust Exposure**: Configured with a `NodePort` service type to cleanly expose the REST API on a dedicated node port (`30007`) for external clients.
- **Cloud Hardened**: Configured with automated kernel tuning workarounds to run smoothly on newer AWS CPU architectures (such as AMD Zen 5) and modern Linux kernels.

---

## 🛠 Tech Stack & Modernizations
- **Backend**: **Flask 3.1.3** & **PyMongo 4.17.0** (coupled with Flask-PyMongo 3.0.1)
  - *Modernization*: Safe, modern database queries using PyMongo 4+ standard `delete_many({})`.
- **Base OS Image**: **Python 3.12-alpine** for lightweight, highly secure, fast container images.
- **Kubernetes Runtimes**: Verified on **K3s**, **Minikube**, and **EKS**.
- **Database**: **MongoDB (Official Latest)** hardened for advanced container platforms.

---

## 📐 Microservice Connection Architecture

Your application is split into a **Frontend/API tier** and a **Database tier**, coordinating seamlessly inside the Kubernetes cluster:

```
                  ┌────────────────────────────────────────┐
                  │          External User Traffic         │
                  └───────────────────┬────────────────────┘
                                      │
                                      ▼ (Port 30007 NodePort)
                  ┌────────────────────────────────────────┐
                  │       taskmaster-svc (Service)         │
                  └───────────────────┬────────────────────┘
                                      │
                                      ▼ (Routes port 80 -> 5000)
                  ┌────────────────────────────────────────┐
                  │         taskmaster (Pod)               │
                  │       - runs flask-task-api            │
                  └───────────────────┬────────────────────┘
                                      │
                      (Connects via: mongodb://mongo:27017)
                                      │
                                      ▼
                  ┌────────────────────────────────────────┐
                  │           mongo (Service)              │
                  └───────────────────┬────────────────────┘
                                      │
                                      ▼ (Routes port 27017 -> 27017)
                  ┌────────────────────────────────────────┐
                  │             mongo (Pod)                │
                  │       - runs official mongo image      │
                  └───────────────────┬────────────────────┘
                                      │
                            (Mounts /data/db to PVC)
                                      ▼
                  ┌────────────────────────────────────────┐
                  │          mongo-pvc (Claim)             │
                  └───────────────────┬────────────────────┘
                                      │
                               (Binds to PV)
                                      ▼
                  ┌────────────────────────────────────────┐
                  │           mongo-pv (Volume)            │
                  └───────────────────┬────────────────────┘
                                      │
                          (Stores data on Host Path)
                                      ▼
                  ┌────────────────────────────────────────┐
                  │     Host Path: /var/data/mongodata     │
                  └────────────────────────────────────────┘
```

---

## 📦 Local Development (Docker)

To run the Flask API locally using raw Docker:

```bash
# Navigate to flask-api folder
cd flask-api

# Build the docker container
docker build -t flask-task-api .

# Run MongoDB container
docker run -d --name local-mongo -p 27017:27017 mongo

# Run the Flask app, connecting it to local MongoDB
docker run -it --name local-api -p 5000:5000 -e MONGO_URI="mongodb://host.docker.internal:27017/dev" flask-task-api
```

---

## ☁️ AWS EC2 & Kubernetes Deployment Guide

### 1. Launch & Configure EC2 Instance
1. Launch an **Ubuntu 22.04 LTS** or **Ubuntu 24.04 LTS** EC2 Instance.
2. Select **t3.medium** (2 vCPUs, 4 GB RAM) for smooth operations (t3.small can work, but avoid t3.micro due to MongoDB memory requirements).
3. Open the following ports in your EC2 Security Group:
   - **22** (SSH) -> Your IP (For administration)
   - **80** (HTTP) -> Anywhere (Standard API traffic)
   - **30007** (Custom TCP) -> Anywhere (External access to NodePort)
4. Connect via SSH:
   ```bash
   ssh -i "your-key.pem" ubuntu@<your-ec2-public-ip>
   ```

### 2. Install Kubernetes (K3s)
We use K3s, a lightweight, highly-optimized Kubernetes distribution:
```bash
# Install K3s
curl -sfL https://get.k3s.io | sh -

# Configure local Kubeconfig permissions (to run kubectl without sudo)
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
```

### 3. Set Up Persistent Host Storage
Create the directory on the host where MongoDB will write its database files and grant appropriate write permissions:
```bash
sudo mkdir -p /var/data/mongodata
sudo chmod 777 /var/data/mongodata
```

### 4. Build & Push Your Custom Docker Image
1. Log in to Docker Hub:
   ```bash
   docker login
   ```
2. Build your Flask API image from the `flask-api` directory:
   ```bash
   docker build -t <your-docker-username>/flask-task-api:latest ./flask-api
   ```
3. Push the image:
   ```bash
   docker push <your-docker-username>/flask-task-api:latest
   ```

> [!TIP]
> After pushing, open `flask-api/k8s/taskmaster.yml` and replace the existing container image field with `<your-docker-username>/flask-task-api:latest`.

### 5. Deploy Microservices to Kubernetes
Apply the Kubernetes manifests in sequence:

```bash
# 1. Apply Persistent Storage
kubectl apply -f flask-api/k8s/mongo-pv.yml
kubectl apply -f flask-api/k8s/mongo-pvc.yml

# 2. Deploy MongoDB Tier
kubectl apply -f flask-api/k8s/mongo-svc.yml
kubectl apply -f flask-api/k8s/mongo.yml

# 3. Deploy Flask API Tier
kubectl apply -f flask-api/k8s/taskmaster.yml
kubectl apply -f flask-api/k8s/taskmaster-svc.yml
```

Verify everything is up and running:
```bash
kubectl get pods -w
```

---

## 🔌 API Endpoint Reference

Once deployed, the NodePort service exposes your Flask API on port **`30007`**. You can interact with it via terminal using **`curl`**:

| HTTP Method | Route | Description | Example Payload / Command |
| :--- | :--- | :--- | :--- |
| **GET** | `/` | Verify API host/pod name | `curl http://localhost:30007/` |
| **GET** | `/tasks` | Retrieve all tasks | `curl http://localhost:30007/tasks` |
| **POST** | `/task` | Create a new task | `curl -X POST -H "Content-Type: application/json" -d '{"task":"Learn Kubernetes"}' http://localhost:30007/task` |
| **PUT** | `/task/<id>` | Update an existing task | `curl -X PUT -H "Content-Type: application/json" -d '{"task":"Complete Course"}' http://localhost:30007/task/<task_id>` |
| **DELETE** | `/task/<id>` | Delete a specific task | `curl -X DELETE http://localhost:30007/task/<task_id>` |
| **POST** | `/tasks/delete` | Wipe database (delete all tasks) | `curl -X POST http://localhost:30007/tasks/delete` |

---

## 🚨 Advanced Troubleshooting Guide

### 1. Exit Code 139: MongoDB Segmentation Fault (SIGSEGV)
- **Symptom**: The MongoDB Pod enters `CrashLoopBackOff`, and `kubectl describe` shows a termination with `Exit Code: 139` (often within 30 seconds of starting up).
- **Cause**: On modern host CPUs (e.g. AMD Zen 5) or new Linux Kernels (6.19+), MongoDB 8.x's default memory allocator (`TCMalloc`) and stack coroutines clash with the CPU's **Hardware Shadow Stack (`SHSTK`)** protection.
- **Fix**: Disable glibc shadow stack validation for the container by adding the `GLIBC_TUNABLES` environment variable to `mongo.yml`:
  ```yaml
        containers:
          - name: mongo
            image: mongo
            env:
              - name: GLIBC_TUNABLES
                value: "glibc.cpu.hwcaps=-SHSTK"
  ```

### 2. Exit Code 62: Wrong mongod Version (FCV Mismatch)
- **Symptom**: The MongoDB Pod crashes on startup with `Exit Code: 62`, logging `Wrong mongod version... UPGRADE PROBLEM: Found an invalid featureCompatibilityVersion document`.
- **Cause**: This happens if you downgrade a database instance that has already run under MongoDB 8.x to an older MongoDB release (like 7.0 or 6.0). The existing data files in `/var/data/mongodata` are formatted for 8.x and cannot be parsed by an older engine.
- **Fix**: Revert to the newer MongoDB image using the Shadow Stack workaround (Option 1 above), or log into the hosting **worker node** and completely wipe the old data files to let MongoDB 7.0 start fresh:
  ```bash
  sudo rm -rf /var/data/mongodata/*
  ```

### 3. Strict Decoding Error (YAML Indentation Error)
- **Symptom**: Running `kubectl apply` results in: `Deployment in version "v1" cannot be handled as a Deployment: strict decoding error: unknown field "spec.template.metadata.spec"`.
- **Cause**: Indentation error inside the deployment file (e.g. `mongo.yml` or `taskmaster.yml`). The `spec:` block under `template:` was accidentally indented too far, making it appear as a child key of `metadata:` instead of its sibling.
- **Fix**: Re-align `spec:` under `template:` to use exactly **4 spaces** of indentation, matching `metadata:` directly. Avoid using tabs inside any YAML manifest.