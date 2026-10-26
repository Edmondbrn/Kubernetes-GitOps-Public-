#/bin/bash

echo "Current cluster:"
kubectl config current context
echo

echo "Cluster nodes:"
kubectl get nodes -o wide
echo

echo "Defaul storage class:"
kubectl get storageclass
echo

echo "Ingress controler:"
kubectl get ingressclass
echo

echo "Cluster pods:"
kubectl get pods -A
echo