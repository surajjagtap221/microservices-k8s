#!/bin/bash
set -e
echo "==== WORKER: Joining Kubernetes cluster ===="
read -p "Paste the kubeadm join command from master: " joincmd
sudo $joincmd --cri-socket unix:///run/containerd/containerd.sock
echo "==== WORKER: Successfully joined cluster! ===="
