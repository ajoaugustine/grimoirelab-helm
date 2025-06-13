# GrimoireLab Installation Guide

## Download and Setup

### Option 1: Download Complete Project

1. **Create a new directory**
   ```bash
   mkdir grimoirelab-deployment
   cd grimoirelab-deployment
   ```

2. **Copy all files from this environment**
   - Chart.yaml
   - values*.yaml files
   - templates/ directory (all subdirectories)
   - scripts/ directory
   - docs/ directory
   - interactive-demo/ directory

3. **Set permissions**
   ```bash
   chmod +x scripts/*.sh
   chmod +x interactive-demo/app.py
   ```

### Option 2: Manual File Creation

Create the following directory structure and copy the files:

```
grimoirelab-helm/
├── Chart.yaml
├── values.yaml
├── values-local.yaml
├── values-production.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── namespace.yaml
│   ├── rbac.yaml
│   ├── serviceaccount.yaml
│   ├── secrets.yaml
│   ├── configmap.yaml
│   ├── ingress.yaml
│   ├── networkpolicy.yaml
│   ├── poddisruptionbudget.yaml
│   ├── elasticsearch/
│   │   ├── configmap.yaml
│   │   ├── service.yaml
│   │   └── statefulset.yaml
│   ├── mariadb/
│   │   ├── configmap.yaml
│   │   ├── secrets.yaml
│   │   ├── service.yaml
│   │   └── statefulset.yaml
│   ├── redis/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── perceval/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── secrets.yaml
│   │   └── service.yaml
│   ├── arthur/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── secrets.yaml
│   │   └── service.yaml
│   ├── graal/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── secrets.yaml
│   │   └── service.yaml
│   ├── sortinghat/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── secrets.yaml
│   │   └── service.yaml
│   ├── sigils/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── kibiter/
│       ├── configmap.yaml
│       ├── deployment.yaml
│       └── service.yaml
├── scripts/
│   ├── setup-local.sh
│   ├── deploy.sh
│   ├── cleanup.sh
│   ├── setup-replit.sh
│   ├── deploy-local-replit.sh
│   └── demo-deployment.sh
├── docs/
│   ├── README.md
│   ├── DEPLOYMENT.md
│   └── TROUBLESHOOTING.md
└── interactive-demo/
    ├── app.py
    └── templates/
        ├── dashboard.html
        ├── perceval.html
        ├── arthur.html
        └── kibiter.html
```

## Prerequisites Installation

### Install Kubernetes Tools

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install kind (for local clusters)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installations
kubectl version --client
helm version
kind version
```

### Install Docker (if needed)

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# CentOS/RHEL
sudo yum install docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

## Deployment Methods

### Method 1: Local Kubernetes with Kind

```bash
# Create local cluster
kind create cluster --name grimoirelab-local --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 5601
    hostPort: 5601
  - containerPort: 8080
    hostPort: 8080
EOF

# Deploy GrimoireLab
helm install grimoirelab . \
  --namespace grimoirelab \
  --create-namespace \
  --values values-local.yaml \
  --wait --timeout 15m

# Access services
kubectl port-forward -n grimoirelab service/grimoirelab-kibiter 5601:5601 &
kubectl port-forward -n grimoirelab service/grimoirelab-arthur 8080:8080 &
```

### Method 2: Using Automated Script

```bash
# Run the complete setup
./scripts/setup-local.sh

# Or for production
./scripts/deploy.sh --environment production
```

### Method 3: Interactive Demo Only

```bash
# Install Python dependencies
pip install flask

# Run demo application
cd interactive-demo/
python app.py

# Visit http://localhost:5000
```

### Method 4: Docker Compose (Alternative)

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.17.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - es_data:/usr/share/elasticsearch/data

  mariadb:
    image: mariadb:10.6
    environment:
      - MYSQL_ROOT_PASSWORD=grimoirelab-root
      - MYSQL_DATABASE=grimoirelab
      - MYSQL_USER=grimoirelab
      - MYSQL_PASSWORD=grimoirelab-pass
    ports:
      - "3306:3306"
    volumes:
      - db_data:/var/lib/mysql

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

  demo-app:
    build: ./interactive-demo
    ports:
      - "5000:5000"
    depends_on:
      - elasticsearch
      - mariadb
      - redis

volumes:
  es_data:
  db_data:
```

## Configuration

### Basic Configuration

Edit `values-local.yaml` for local development:

```yaml
# Resource limits for local development
elasticsearch:
  replicas: 1
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"

mariadb:
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"

# Disable resource-intensive features for local testing
networkPolicy:
  enabled: false

ingress:
  enabled: false
```

### Production Configuration

Edit `values-production.yaml`:

```yaml
# Production settings
elasticsearch:
  replicas: 3
  resources:
    requests:
      memory: "4Gi"
      cpu: "2000m"
  persistence:
    size: 50Gi

mariadb:
  auth:
    rootPassword: "your-secure-password"
    password: "your-secure-password"

ingress:
  enabled: true
  hosts:
    - host: grimoirelab.yourdomain.com
```

## Testing and Validation

### Validate Helm Chart

```bash
# Lint the chart
helm lint . --values values-local.yaml

# Generate templates (dry run)
helm template grimoirelab . \
  --values values-local.yaml \
  --namespace grimoirelab \
  --output-dir output/

# Check generated manifests
find output/ -name "*.yaml" | head -10
```

### Monitor Deployment

```bash
# Check pod status
kubectl get pods -n grimoirelab -w

# View logs
kubectl logs -n grimoirelab -l app.kubernetes.io/name=grimoirelab -f

# Check services
kubectl get svc -n grimoirelab

# Describe issues
kubectl describe pod -n grimoirelab <pod-name>
```

### Access Applications

```bash
# Port forwarding
kubectl port-forward -n grimoirelab service/grimoirelab-kibiter 5601:5601 &
kubectl port-forward -n grimoirelab service/grimoirelab-arthur 8080:8080 &
kubectl port-forward -n grimoirelab service/grimoirelab-elasticsearch 9200:9200 &

# Test connectivity
curl http://localhost:9200/_cluster/health
curl http://localhost:5601
curl http://localhost:8080
```

## Cleanup

```bash
# Remove deployment
helm uninstall grimoirelab -n grimoirelab

# Remove namespace
kubectl delete namespace grimoirelab

# Remove cluster
kind delete cluster --name grimoirelab-local

# Or use cleanup script
./scripts/cleanup.sh --remove-cluster
```

## Troubleshooting

### Common Issues

1. **Insufficient Resources**
   ```bash
   # Check node resources
   kubectl top nodes
   kubectl describe nodes
   ```

2. **Storage Issues**
   ```bash
   # Check persistent volumes
   kubectl get pv,pvc -n grimoirelab
   ```

3. **Network Issues**
   ```bash
   # Check services and endpoints
   kubectl get svc,endpoints -n grimoirelab
   ```

4. **Image Pull Issues**
   ```bash
   # Check image pull secrets
   kubectl get secrets -n grimoirelab
   ```

### Debug Commands

```bash
# Get all resources
kubectl get all -n grimoirelab

# View events
kubectl get events -n grimoirelab --sort-by='.lastTimestamp'

# Check Helm release
helm status grimoirelab -n grimoirelab
helm history grimoirelab -n grimoirelab

# Exec into pods
kubectl exec -it -n grimoirelab <pod-name> -- /bin/bash
```

## Next Steps

1. **Access the demo**: http://localhost:5000
2. **Explore dashboards**: http://localhost:5601
3. **Check API endpoints**: http://localhost:8080
4. **Monitor with kubectl**: `kubectl get pods -n grimoirelab`
5. **View logs**: `kubectl logs -n grimoirelab -l app.kubernetes.io/name=grimoirelab`

## Support

- Check the logs first: `kubectl logs -n grimoirelab <pod-name>`
- Review the troubleshooting guide: `docs/TROUBLESHOOTING.md`
- Validate configuration: `helm lint . --values values-local.yaml`