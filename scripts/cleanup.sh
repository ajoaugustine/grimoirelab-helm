#!/bin/bash

# GrimoireLab Cleanup Script
# This script removes GrimoireLab deployment and optionally the cluster

set -e

# Default values
NAMESPACE="grimoirelab"
HELM_RELEASE="grimoirelab"
CLUSTER_NAME="grimoirelab-local"
REMOVE_CLUSTER="false"
REMOVE_PVC="false"
FORCE="false"

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

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace (default: grimoirelab)"
    echo "  -r, --release RELEASE        Helm release name (default: grimoirelab)"
    echo "  -c, --cluster CLUSTER        Local cluster name (default: grimoirelab-local)"
    echo "  --remove-cluster            Remove the entire local cluster"
    echo "  --remove-pvc                Remove persistent volume claims"
    echo "  -f, --force                 Force removal without confirmation"
    echo "  -h, --help                  Show this help message"
    echo
    echo "Examples:"
    echo "  $0                          # Remove only the Helm release"
    echo "  $0 --remove-pvc             # Remove release and PVCs"
    echo "  $0 --remove-cluster         # Remove entire local cluster"
    echo "  $0 --force --remove-cluster # Force remove cluster without confirmation"
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
            -c|--cluster)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --remove-cluster)
                REMOVE_CLUSTER="true"
                shift
                ;;
            --remove-pvc)
                REMOVE_PVC="true"
                shift
                ;;
            -f|--force)
                FORCE="true"
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

# Confirm action
confirm_action() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    local message="$1"
    echo -n -e "${YELLOW}[CONFIRM]${NC} $message (y/N): "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            log_info "Operation cancelled"
            exit 0
            ;;
    esac
}

# Remove Helm release
remove_helm_release() {
    log_info "Checking for Helm release: $HELM_RELEASE"
    
    if helm list -n "$NAMESPACE" | grep -q "$HELM_RELEASE"; then
        confirm_action "Remove Helm release '$HELM_RELEASE' from namespace '$NAMESPACE'?"
        
        log_info "Removing Helm release: $HELM_RELEASE"
        helm uninstall "$HELM_RELEASE" -n "$NAMESPACE"
        log_info "Helm release removed successfully"
    else
        log_warn "Helm release '$HELM_RELEASE' not found in namespace '$NAMESPACE'"
    fi
}

# Remove persistent volume claims
remove_pvcs() {
    if [[ "$REMOVE_PVC" != "true" ]]; then
        return 0
    fi
    
    log_info "Checking for persistent volume claims..."
    
    local pvcs
    pvcs=$(kubectl get pvc -n "$NAMESPACE" -o name 2>/dev/null | grep grimoirelab || true)
    
    if [[ -n "$pvcs" ]]; then
        confirm_action "Remove all GrimoireLab persistent volume claims? This will delete all data!"
        
        log_info "Removing persistent volume claims..."
        kubectl delete pvc -n "$NAMESPACE" -l app.kubernetes.io/instance="$HELM_RELEASE"
        log_info "Persistent volume claims removed"
    else
        log_info "No GrimoireLab PVCs found"
    fi
}

# Remove namespace
remove_namespace() {
    log_info "Checking namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        # Check if namespace has other resources
        local resources
        resources=$(kubectl get all -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        if [[ "$resources" -eq 0 ]]; then
            log_info "Removing empty namespace: $NAMESPACE"
            kubectl delete namespace "$NAMESPACE"
            log_info "Namespace removed"
        else
            log_warn "Namespace '$NAMESPACE' contains other resources, skipping removal"
        fi
    else
        log_info "Namespace '$NAMESPACE' not found"
    fi
}

# Stop port forwarding
stop_port_forwarding() {
    log_info "Stopping port forwarding processes..."
    
    local pids
    pids=$(pgrep -f "kubectl.*port-forward.*grimoirelab" || true)
    
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill
        log_info "Port forwarding processes stopped"
    else
        log_info "No port forwarding processes found"
    fi
}

# Remove local cluster
remove_cluster() {
    if [[ "$REMOVE_CLUSTER" != "true" ]]; then
        return 0
    fi
    
    confirm_action "Remove entire local cluster '$CLUSTER_NAME'? This will delete everything!"
    
    log_info "Removing local cluster..."
    
    if command -v kind &> /dev/null; then
        if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
            kind delete cluster --name "$CLUSTER_NAME"
            log_info "Kind cluster removed successfully"
        else
            log_warn "Kind cluster '$CLUSTER_NAME' not found"
        fi
    elif command -v minikube &> /dev/null; then
        if minikube status -p "$CLUSTER_NAME" &> /dev/null; then
            minikube delete -p "$CLUSTER_NAME"
            log_info "Minikube cluster removed successfully"
        else
            log_warn "Minikube cluster '$CLUSTER_NAME' not found"
        fi
    else
        log_warn "No local cluster tool found (kind/minikube)"
    fi
}

# Show cleanup summary
show_summary() {
    log_info "Cleanup Summary:"
    echo
    echo "=== Actions Performed ==="
    echo "- Removed Helm release: $HELM_RELEASE"
    
    if [[ "$REMOVE_PVC" == "true" ]]; then
        echo "- Removed persistent volume claims"
    fi
    
    if [[ "$REMOVE_CLUSTER" == "true" ]]; then
        echo "- Removed local cluster: $CLUSTER_NAME"
    fi
    
    echo "- Stopped port forwarding processes"
    echo
    log_info "Cleanup completed successfully!"
}

# Main execution
main() {
    log_info "Starting GrimoireLab cleanup..."
    
    parse_args "$@"
    
    # Stop port forwarding first
    stop_port_forwarding
    
    if [[ "$REMOVE_CLUSTER" == "true" ]]; then
        # If removing cluster, no need to remove individual components
        remove_cluster
    else
        # Remove components individually
        remove_helm_release
        remove_pvcs
        remove_namespace
    fi
    
    show_summary
}

# Handle script interruption
cleanup() {
    log_warn "Script interrupted"
    exit 1
}

trap cleanup INT TERM

# Run main function
main "$@"
