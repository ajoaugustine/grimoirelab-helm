#!/bin/bash

# GrimoireLab Local Setup Script
# This script sets up a local Kubernetes cluster and deploys GrimoireLab

set -e

# Configuration
CLUSTER_NAME="grimoirelab-local"
NAMESPACE="grimoirelab"
HELM_RELEASE="grimoirelab"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed. Please install helm first."
        exit 1
    fi
    
    if ! command -v kind &> /dev/null && ! command -v minikube &> /dev/null; then
        log_error "Neither kind nor minikube is installed. Please install one of them."
        exit 1
    fi
}

# Create local Kubernetes cluster
create_cluster() {
    log_info "Creating local Kubernetes cluster..."
    
    if command -v kind &> /dev/null; then
        # Use kind
        if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
            log_warn "Kind cluster '${CLUSTER_NAME}' already exists. Skipping creation."
        else
            cat <<EOF | kind create cluster --name ${CLUSTER_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 5601
    hostPort: 5601
    protocol: TCP
- role: worker
- role: worker
EOF
            log_info "Kind cluster created successfully"
        fi
        
        # Switch context
        kubectl cluster-info --context kind-${CLUSTER_NAME}
        
    elif command -v minikube &> /dev/null; then
        # Use minikube
        if minikube status -p ${CLUSTER_NAME} &> /dev/null; then
            log_warn "Minikube cluster '${CLUSTER_NAME}' already exists. Skipping creation."
        else
            minikube start -p ${CLUSTER_NAME} --nodes 3 --cpus 4 --memory 8192
            log_info "Minikube cluster created successfully"
        fi
        
        # Switch context
        kubectl config use-context ${CLUSTER_NAME}
    fi
}

# Install ingress controller
install_ingress() {
    log_info "Installing NGINX Ingress Controller..."
    
    if command -v kind &> /dev/null; then
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    else
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
    fi
    
    log_info "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
}

# Deploy GrimoireLab
deploy_grimoirelab() {
    log_info "Deploying GrimoireLab..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    # Install/upgrade helm chart
    helm upgrade --install ${HELM_RELEASE} . \
        --namespace ${NAMESPACE} \
        --values values-local.yaml \
        --wait \
        --timeout 10m
    
    log_info "GrimoireLab deployed successfully"
}

# Wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    # Wait for Elasticsearch
    kubectl wait --namespace ${NAMESPACE} \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=elasticsearch \
        --timeout=300s
    
    # Wait for MariaDB
    kubectl wait --namespace ${NAMESPACE} \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=mariadb \
        --timeout=300s
    
    # Wait for Kibiter
    kubectl wait --namespace ${NAMESPACE} \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=kibiter \
        --timeout=300s
    
    log_info "All services are ready"
}

# Setup port forwarding
setup_port_forwarding() {
    log_info "Setting up port forwarding..."
    
    # Kill existing port-forwards
    pkill -f "kubectl.*port-forward" || true
    
    # Forward Kibiter
    kubectl port-forward -n ${NAMESPACE} service/grimoirelab-kibiter 5601:5601 &
    
    # Forward Arthur API
    kubectl port-forward -n ${NAMESPACE} service/grimoirelab-arthur 8080:8080 &
    
    log_info "Port forwarding setup complete"
    log_info "Kibiter UI: http://localhost:5601"
    log_info "Arthur API: http://localhost:8080"
}

# Display cluster information
display_info() {
    log_info "Deployment completed successfully!"
    echo
    echo "=== Access Information ==="
    echo "Kibiter Dashboard: http://localhost:5601"
    echo "Arthur API: http://localhost:8080"
    echo
    echo "=== Useful Commands ==="
    echo "View pods: kubectl get pods -n ${NAMESPACE}"
    echo "View services: kubectl get services -n ${NAMESPACE}"
    echo "View logs: kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=grimoirelab"
    echo "Delete deployment: helm uninstall ${HELM_RELEASE} -n ${NAMESPACE}"
    echo
}

# Main execution
main() {
    log_info "Starting GrimoireLab local setup..."
    
    check_prerequisites
    create_cluster
    install_ingress
    deploy_grimoirelab
    wait_for_services
    setup_port_forwarding
    display_info
    
    log_info "Setup completed successfully!"
}

# Handle script interruption
cleanup() {
    log_warn "Script interrupted. Cleaning up..."
    pkill -f "kubectl.*port-forward" || true
    exit 1
}

trap cleanup INT TERM

# Run main function
main "$@"
