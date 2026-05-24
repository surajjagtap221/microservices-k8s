#!/bin/bash
set -e
echo "==== MASTER: Initializing Kubernetes Control Plane ===="

# Initialize Kubernetes with containerd
sudo kubeadm init --cri-socket unix:///run/containerd/containerd.sock --pod-network-cidr=10.244.0.0/16

# Setup kubeconfig for the ubuntu user automatically
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "Kubeconfig setup complete."

# Deploy Flannel CNI plugin
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
echo "==== MASTER: Kubernetes Control Plane is ready ===="
echo "Run this command to get join token for workers:"
echo "  kubeadm token create --print-join-command"
