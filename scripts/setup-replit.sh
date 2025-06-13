#!/bin/bash

# GrimoireLab Replit Setup Script
# This script demonstrates the Helm chart without requiring a full Kubernetes cluster

set -e

# Configuration
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
    
    log_info "Prerequisites check passed"
}

# Validate Helm chart
validate_chart() {
    log_info "Validating Helm chart..."
    
    # Lint the chart
    if ! helm lint . --values values-local.yaml; then
        log_error "Helm chart validation failed"
        exit 1
    fi
    
    log_info "Chart validation passed"
}

# Generate templates to show what would be deployed
generate_templates() {
    log_info "Generating Kubernetes manifests..."
    
    # Create output directory
    mkdir -p output
    
    # Generate templates for local environment
    helm template "$HELM_RELEASE" . \
        --values values-local.yaml \
        --namespace "$NAMESPACE" \
        --output-dir output/
    
    log_info "Templates generated in output/ directory"
}

# Show deployment information
show_deployment_info() {
    log_info "GrimoireLab Helm Chart Overview"
    echo
    echo "=== Chart Information ==="
    helm show chart .
    echo
    echo "=== Generated Files ==="
    find output/ -name "*.yaml" | sort
    echo
    echo "=== Resource Summary ==="
    
    # Count different resource types
    local deployments=$(find output/ -name "*.yaml" -exec grep -l "kind: Deployment" {} \; | wc -l)
    local services=$(find output/ -name "*.yaml" -exec grep -l "kind: Service" {} \; | wc -l)
    local configmaps=$(find output/ -name "*.yaml" -exec grep -l "kind: ConfigMap" {} \; | wc -l)
    local secrets=$(find output/ -name "*.yaml" -exec grep -l "kind: Secret" {} \; | wc -l)
    local statefulsets=$(find output/ -name "*.yaml" -exec grep -l "kind: StatefulSet" {} \; | wc -l)
    
    echo "Deployments: $deployments"
    echo "Services: $services"
    echo "ConfigMaps: $configmaps"
    echo "Secrets: $secrets"
    echo "StatefulSets: $statefulsets"
    echo
}

# Show configuration details
show_configuration() {
    log_info "Configuration Details"
    echo
    echo "=== Local Environment Values ==="
    echo "File: values-local.yaml"
    echo
    helm show values . | head -50
    echo "... (truncated, see values.yaml for full configuration)"
    echo
    echo "=== Key Components ==="
    echo "Infrastructure:"
    echo "- Elasticsearch: Search and analytics engine"
    echo "- MariaDB: Relational database for metadata"
    echo "- Redis: Caching and message queuing"
    echo
    echo "GrimoireLab Services:"
    echo "- Perceval: Data collection from multiple sources"
    echo "- Arthur: Job scheduling and orchestration"
    echo "- Graal: Source code analysis and metrics"
    echo "- SortingHat: Identity management"
    echo "- Sigils: Data visualization templates"
    echo "- Kibiter: Customized Kibana dashboard"
    echo
}

# Show deployment instructions
show_deployment_instructions() {
    log_info "Deployment Instructions"
    echo
    echo "=== For Local Kubernetes Cluster ==="
    echo "1. Install kind or minikube:"
    echo "   kind create cluster --name grimoirelab-local"
    echo "   OR"
    echo "   minikube start --profile grimoirelab-local"
    echo
    echo "2. Deploy using the provided script:"
    echo "   ./scripts/setup-local.sh"
    echo
    echo "3. Or deploy manually:"
    echo "   helm install grimoirelab . --namespace grimoirelab --create-namespace --values values-local.yaml"
    echo
    echo "=== For Production Kubernetes Cluster ==="
    echo "1. Update values-production.yaml with your environment settings"
    echo "2. Deploy using:"
    echo "   ./scripts/deploy.sh --environment production"
    echo
    echo "=== Access Information ==="
    echo "After deployment, services will be available at:"
    echo "- Kibiter Dashboard: http://localhost:5601 (with port forwarding)"
    echo "- Arthur API: http://localhost:8080 (with port forwarding)"
    echo
    echo "Port forwarding commands:"
    echo "kubectl port-forward -n grimoirelab service/grimoirelab-kibiter 5601:5601"
    echo "kubectl port-forward -n grimoirelab service/grimoirelab-arthur 8080:8080"
    echo
}

# Main execution
main() {
    log_info "Starting GrimoireLab Helm chart demonstration..."
    
    check_prerequisites
    validate_chart
    generate_templates
    show_deployment_info
    show_configuration
    show_deployment_instructions
    
    log_info "Helm chart demonstration completed successfully!"
    log_info "Check the output/ directory for generated Kubernetes manifests"
}

# Handle script interruption
cleanup() {
    log_warn "Script interrupted"
    exit 1
}

trap cleanup INT TERM

# Run main function
main "$@"