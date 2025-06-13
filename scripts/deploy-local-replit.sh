#!/bin/bash

# GrimoireLab Local Deployment for Replit
# This script creates a local kind cluster and deploys GrimoireLab

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

# Check if Docker daemon is running
check_docker() {
    log_info "Checking Docker daemon..."
    if ! docker info &> /dev/null; then
        log_info "Starting Docker daemon..."
        # In Replit, docker daemon may need to be started
        sudo dockerd &
        sleep 10
        
        # Wait for docker to be ready
        for i in {1..30}; do
            if docker info &> /dev/null; then
                log_info "Docker daemon is running"
                return 0
            fi
            sleep 2
        done
        
        log_error "Failed to start Docker daemon"
        return 1
    fi
    log_info "Docker daemon is running"
}

# Create local Kubernetes cluster
create_cluster() {
    log_info "Creating local Kubernetes cluster with kind..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Kind cluster '${CLUSTER_NAME}' already exists. Deleting and recreating..."
        kind delete cluster --name ${CLUSTER_NAME}
    fi
    
    # Create cluster configuration
    cat <<EOF > kind-config.yaml
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
  - containerPort: 8080
    hostPort: 8080
    protocol: TCP
EOF
    
    # Create the cluster
    kind create cluster --name ${CLUSTER_NAME} --config=kind-config.yaml
    
    # Switch context
    kubectl cluster-info --context kind-${CLUSTER_NAME}
    
    log_info "Kind cluster created successfully"
}

# Install ingress controller
install_ingress() {
    log_info "Installing NGINX Ingress Controller..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
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
        --timeout 15m
    
    log_info "GrimoireLab deployed successfully"
}

# Wait for core services to be ready
wait_for_services() {
    log_info "Waiting for core services to be ready..."
    
    # Wait for Elasticsearch
    log_info "Waiting for Elasticsearch..."
    kubectl wait --namespace ${NAMESPACE} \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=elasticsearch \
        --timeout=600s
    
    # Wait for MariaDB
    log_info "Waiting for MariaDB..."
    kubectl wait --namespace ${NAMESPACE} \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=mariadb \
        --timeout=300s
    
    # Wait for Redis
    log_info "Waiting for Redis..."
    kubectl wait --namespace ${NAMESPACE} \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=redis \
        --timeout=180s
    
    # Wait for Kibiter
    log_info "Waiting for Kibiter..."
    kubectl wait --namespace ${NAMESPACE} \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=kibiter \
        --timeout=300s
    
    log_info "All core services are ready"
}

# Setup port forwarding
setup_port_forwarding() {
    log_info "Setting up port forwarding..."
    
    # Kill existing port-forwards
    pkill -f "kubectl.*port-forward" || true
    
    # Wait a moment for processes to clean up
    sleep 2
    
    # Forward Kibiter (dashboard)
    kubectl port-forward -n ${NAMESPACE} service/grimoirelab-kibiter 5601:5601 &
    
    # Forward Arthur API
    kubectl port-forward -n ${NAMESPACE} service/grimoirelab-arthur 8080:8080 &
    
    # Forward Elasticsearch for direct access
    kubectl port-forward -n ${NAMESPACE} service/grimoirelab-elasticsearch 9200:9200 &
    
    log_info "Port forwarding setup complete"
}

# Display deployment status and access information
display_info() {
    log_info "Deployment Status:"
    echo
    
    # Show pods
    echo "=== Pods Status ==="
    kubectl get pods -n ${NAMESPACE}
    echo
    
    # Show services
    echo "=== Services ==="
    kubectl get services -n ${NAMESPACE}
    echo
    
    log_info "Access Information:"
    echo "Kibiter Dashboard: http://localhost:5601"
    echo "Arthur API: http://localhost:8080"
    echo "Elasticsearch: http://localhost:9200"
    echo
    echo "=== Useful Commands ==="
    echo "View all pods: kubectl get pods -n ${NAMESPACE}"
    echo "Check pod logs: kubectl logs -n ${NAMESPACE} <pod-name>"
    echo "Scale deployment: kubectl scale deployment -n ${NAMESPACE} <deployment-name> --replicas=<number>"
    echo "Delete deployment: helm uninstall ${HELM_RELEASE} -n ${NAMESPACE}"
    echo "Delete cluster: kind delete cluster --name ${CLUSTER_NAME}"
    echo
    
    log_info "GrimoireLab is now running!"
    log_info "The services will be accessible once all pods are fully started."
}

# Test services
test_services() {
    log_info "Testing service connectivity..."
    
    # Test Elasticsearch
    if curl -s http://localhost:9200/_cluster/health > /dev/null; then
        log_info "✓ Elasticsearch is responding"
    else
        log_warn "✗ Elasticsearch not yet responding (may still be starting)"
    fi
    
    # Test Kibiter
    if curl -s http://localhost:5601 > /dev/null; then
        log_info "✓ Kibiter is responding"
    else
        log_warn "✗ Kibiter not yet responding (may still be starting)"
    fi
}

# Main execution
main() {
    log_info "Starting GrimoireLab local deployment..."
    
    check_docker
    create_cluster
    install_ingress
    deploy_grimoirelab
    wait_for_services
    setup_port_forwarding
    display_info
    
    # Wait a bit for port forwarding to establish
    sleep 5
    test_services
    
    log_info "Deployment completed successfully!"
    log_info "Services are starting up and will be available shortly at the URLs above."
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