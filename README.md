# GrimoireLab Helm Chart

A production-ready Helm chart for deploying the complete GrimoireLab microservices architecture on Kubernetes.

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🚀 Overview

GrimoireLab is a toolkit for software development analytics that provides insights into software projects through data collection, processing, and visualization. This Helm chart packages all necessary components for a production-ready deployment.

### Architecture Components

**Infrastructure Services:**
- **Elasticsearch 7.17.0** - Search and analytics engine
- **MariaDB 10.6** - Relational database for metadata
- **Redis** - Caching and message queuing

**GrimoireLab Services:**
- **Perceval** - Data collection from multiple sources (Git, GitHub, JIRA, etc.)
- **Arthur** - Job scheduling and orchestration
- **Graal** - Source code analysis and metrics extraction
- **SortingHat** - Identity management and unification
- **Sigils** - Data visualization templates
- **Kibiter** - Customized Kibana for analytics

### Prerequisites

- Kubernetes cluster (v1.19+)
- Helm 3.x
- kubectl configured
- 8GB+ RAM and 4+ CPU cores
- 50GB+ storage

### One-Command Deployment

```bash
# Clone the repository
git clone <your-repo-url>
cd grimoirelab-helm

# Deploy to local cluster
./scripts/setup-local.sh
```

### Manual Deployment

```bash
# Create cluster (using kind)
kind create cluster --name grimoirelab-local

# Deploy GrimoireLab
helm install grimoirelab . \
  --namespace grimoirelab \
  --create-namespace \
  --values values-local.yaml

# Access services
kubectl port-forward -n grimoirelab service/grimoirelab-kibiter 5601:5601
kubectl port-forward -n grimoirelab service/grimoirelab-arthur 8080:8080
```

## 📦 Installation

### Local Development

1. **Install Dependencies**
   ```bash
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl && sudo mv kubectl /usr/local/bin/

   # Install Helm
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

   # Install kind (for local clusters)
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
   chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
   ```

2. **Deploy Locally**
   ```bash
   chmod +x scripts/*.sh
   ./scripts/setup-local.sh
   ```

### Production Deployment

1. **Configure Production Values**
   ```bash
   cp values.yaml values-production.yaml
   # Edit values-production.yaml with your settings
   ```

2. **Deploy to Production**
   ```bash
   ./scripts/deploy.sh --environment production
   ```

### Using Docker Compose (Alternative)

For development without Kubernetes:

```bash
cd docker-compose/
docker-compose up -d
```

## ⚙️ Configuration

### Environment Files

- **`values.yaml`** - Base configuration
- **`values-local.yaml`** - Local development settings
- **`values-production.yaml`** - Production configuration

### Key Configuration Sections

#### Elasticsearch
```yaml
elasticsearch:
  enabled: true
  replicas: 3
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
  persistence:
    enabled: true
    size: 20Gi
```

#### MariaDB
```yaml
mariadb:
  enabled: true
  auth:
    rootPassword: "your-secure-password"
    database: "grimoirelab"
    username: "grimoirelab"
    password: "your-password"
```

#### Ingress
```yaml
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: grimoirelab.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
          service: kibiter
```

### Resource Requirements

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| Elasticsearch | 1-2 cores | 2-4GB | 20GB |
| MariaDB | 250m-1 core | 512MB-1GB | 10GB |
| Each Service | 100-500m | 256-512MB | - |

## 🔧 Development

### Interactive Demo

Test the interfaces locally:

```bash
cd interactive-demo/
python -m pip install flask
python app.py
# Visit http://localhost:5000
```

### Validate Chart

```bash
# Lint the chart
helm lint . --values values-local.yaml

# Generate manifests
helm template grimoirelab . \
  --values values-local.yaml \
  --namespace grimoirelab \
  --output-dir output/
```

### Testing

```bash
# Test deployment
./scripts/deploy.sh --dry-run --environment local

# Check generated resources
kubectl get all -n grimoirelab

# Monitor pods
kubectl logs -n grimoirelab -l app.kubernetes.io/name=grimoirelab -f
```

## 🌐 Access URLs

After deployment:

- **Kibiter Dashboard**: http://localhost:5601
- **Arthur API**: http://localhost:8080
- **Elasticsearch**: http://localhost:9200

With ingress (production):
- **Main Dashboard**: https://grimoirelab.yourdomain.com
- **API Endpoints**: https://grimoirelab.yourdomain.com/api

## 🐛 Troubleshooting

### Common Issues

1. **Pods stuck in Pending**
   ```bash
   kubectl describe pod -n grimoirelab <pod-name>
   # Check resource constraints and storage
   ```

2. **Elasticsearch won't start**
   ```bash
   # Check if vm.max_map_count is set correctly
   kubectl logs -n grimoirelab -l app.kubernetes.io/component=elasticsearch
   ```

3. **Services not accessible**
   ```bash
   # Verify port forwarding
   kubectl get svc -n grimoirelab
   kubectl port-forward -n grimoirelab service/grimoirelab-kibiter 5601:5601
   ```

### Debug Commands

```bash
# Check all resources
kubectl get all -n grimoirelab

# View events
kubectl get events -n grimoirelab --sort-by='.lastTimestamp'

# Check persistent volumes
kubectl get pv,pvc -n grimoirelab

# Helm status
helm status grimoirelab -n grimoirelab
```

## 🧹 Cleanup

```bash
# Remove deployment
helm uninstall grimoirelab -n grimoirelab

# Remove namespace
kubectl delete namespace grimoirelab

# Remove local cluster
kind delete cluster --name grimoirelab-local

# Or use cleanup script
./scripts/cleanup.sh --remove-cluster
```

## 📁 Project Structure

```
grimoirelab-helm/
├── Chart.yaml                 # Helm chart metadata
├── values*.yaml              # Configuration files
├── templates/                 # Kubernetes manifests
│   ├── elasticsearch/         # Search engine
│   ├── mariadb/              # Database
│   ├── redis/                # Cache
│   ├── perceval/             # Data collection
│   ├── arthur/               # Job management
│   ├── graal/                # Code analysis
│   ├── sortinghat/           # Identity management
│   ├── sigils/               # Visualization
│   ├── kibiter/              # Dashboard
│   └── _helpers.tpl          # Template helpers
├── scripts/                   # Deployment scripts
├── docs/                     # Documentation
├── interactive-demo/         # Web demo
└── docker-compose/          # Alternative deployment
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request

### Development Workflow

```bash
# Test changes locally
helm lint . --values values-local.yaml

# Validate templates
helm template grimoirelab . --values values-local.yaml --debug

# Test deployment
./scripts/deploy.sh --dry-run --environment local
```

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🔗 Links

- [GrimoireLab Documentation](https://grimoirelab.github.io/)
- [CHAOSS Community](https://chaoss.community/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

## 📞 Support

- GitHub Issues: [Create an issue](https://github.com/your-repo/issues)
- Community: [GrimoireLab Discussions](https://grimoirelab-discussions@lists.linuxfoundation.org)
- Documentation: [docs/](docs/)
