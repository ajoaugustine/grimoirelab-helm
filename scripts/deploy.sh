#!/bin/bash

# GrimoireLab Deployment Script
# This script deploys GrimoireLab to an existing Kubernetes cluster

set -e

# Default values
NAMESPACE="grimoirelab"
HELM_RELEASE="grimoirelab"
VALUES_FILE="values.yaml"
TIMEOUT="15m"
DRY_RUN="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace (default: grimoirelab)"
    echo "  -r, --release RELEASE        Helm release name (default: grimoirelab)"
    echo "  -f, --values VALUES_FILE     Values file to use (default: values.yaml)"
    echo "  -e, --environment ENV        Environment (local, staging, production)"
    echo "  -t, --timeout TIMEOUT        Timeout for deployment (default: 15m)"
    echo "  -d, --dry-run               Perform a dry run"
    echo "  -u, --upgrade               Upgrade existing deployment"
    echo "  -h, --help                  Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --environment local"
    echo "  $0 --namespace prod --environment production --upgrade"
    echo "  $0 --dry-run --values values-staging.yaml"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -r|--release)
                HELM_RELEASE="$2"
                shift 2
                ;;
            -f|--values)
                VALUES_FILE="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                case $ENVIRONMENT in
                    local)
                        VALUES_FILE="values-local.yaml"
                        ;;
                    staging)
                        VALUES_FILE="values-staging.yaml"
                        ;;
                    production)
                        VALUES_FILE="values-production.yaml"
                        ;;
                    *)
                        log_error "Unknown environment: $ENVIRONMENT"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -u|--upgrade)
                UPGRADE="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check values file exists
    if [[ ! -f "$VALUES_FILE" ]]; then
        log_error "Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Validate Helm chart
validate_chart() {
    log_info "Validating Helm chart..."
    
    # Lint the chart
    if ! helm lint . --values "$VALUES_FILE"; then
        log_error "Helm chart validation failed"
        exit 1
    fi
    
    # Template the chart to check for issues
    if ! helm template "$HELM_RELEASE" . --values "$VALUES_FILE" --namespace "$NAMESPACE" > /dev/null; then
        log_error "Helm chart templating failed"
        exit 1
    fi
    
    log_info "Chart validation passed"
}

# Create namespace if it doesn't exist
create_namespace() {
    log_info "Ensuring namespace exists: $NAMESPACE"
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        kubectl create namespace "$NAMESPACE"
        log_info "Created namespace: $NAMESPACE"
    else
        log_info "Namespace already exists: $NAMESPACE"
    fi
}

# Deploy or upgrade GrimoireLab
deploy() {
    log_info "Deploying GrimoireLab..."
    
    local helm_args=(
        "$HELM_RELEASE"
        .
        --namespace "$NAMESPACE"
        --values "$VALUES_FILE"
        --timeout "$TIMEOUT"
        --wait
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        helm_args+=(--dry-run)
        log_info "Performing dry run..."
    fi
    
    if [[ "$UPGRADE" == "true" ]] || helm list -n "$NAMESPACE" | grep -q "$HELM_RELEASE"; then
        log_info "Upgrading existing release..."
        helm upgrade --install "${helm_args[@]}"
    else
        log_info "Installing new release..."
        helm install "${helm_args[@]}"
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Deployment completed successfully"
    else
        log_info "Dry run completed successfully"
    fi
}

# Wait for deployment to be ready
wait_for_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log_info "Waiting for deployment to be ready..."
    
    # Wait for critical services
    log_info "Waiting for Elasticsearch..."
    kubectl wait --namespace "$NAMESPACE" \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=elasticsearch \
        --timeout=300s
    
    log_info "Waiting for MariaDB..."
    kubectl wait --namespace "$NAMESPACE" \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=mariadb \
        --timeout=300s
    
    log_info "Waiting for Kibiter..."
    kubectl wait --namespace "$NAMESPACE" \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=kibiter \
        --timeout=300s
    
    log_info "All services are ready"
}

# Show deployment status
show_status() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log_info "Deployment Status:"
    echo
    
    # Show helm release status
    helm status "$HELM_RELEASE" -n "$NAMESPACE"
    echo
    
    # Show pods status
    echo "=== Pods ==="
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$HELM_RELEASE"
    echo
    
    # Show services
    echo "=== Services ==="
    kubectl get services -n "$NAMESPACE" -l app.kubernetes.io/instance="$HELM_RELEASE"
    echo
    
    # Show ingress
    echo "=== Ingress ==="
    kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/instance="$HELM_RELEASE" 2>/dev/null || echo "No ingress found"
    echo
}

# Show access information
show_access_info() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log_info "Access Information:"
    echo
    
    # Get ingress information
    local ingress_host
    ingress_host=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
    
    if [[ -n "$ingress_host" ]]; then
        echo "Kibiter Dashboard: http://$ingress_host"
        echo "Arthur API: http://$ingress_host/api"
    else
        echo "To access the services, you can use port forwarding:"
        echo "kubectl port-forward -n $NAMESPACE service/$HELM_RELEASE-kibiter 5601:5601"
        echo "kubectl port-forward -n $NAMESPACE service/$HELM_RELEASE-arthur 8080:8080"
    fi
    echo
}

# Main execution
main() {
    log_info "Starting GrimoireLab deployment..."
    
    parse_args "$@"
    check_prerequisites
    validate_chart
    create_namespace
    deploy
    wait_for_deployment
    show_status
    show_access_info
    
    log_info "Deployment script completed successfully!"
}

# Handle script interruption
cleanup() {
    log_warn "Script interrupted"
    exit 1
}

trap cleanup INT TERM

# Run main function
main "$@"
