# Download and Deploy GrimoireLab

## Quick Download Commands

### Method 1: Individual File Downloads

Copy these files to your local machine in the specified directory structure:

```bash
# Create project directory
mkdir grimoirelab-helm && cd grimoirelab-helm

# Create required directories
mkdir -p templates/{elasticsearch,mariadb,redis,perceval,arthur,graal,sortinghat,sigils,kibiter}
mkdir -p scripts docs interactive-demo/templates
```

**Core Files to Copy:**
- `Chart.yaml`
- `values.yaml` 
- `values-local.yaml`
- `values-production.yaml`
- `README.md`
- `INSTALLATION_GUIDE.md`

**Template Files:** (Copy all files from each subdirectory)
- `templates/_helpers.tpl`
- `templates/namespace.yaml`
- `templates/rbac.yaml`
- `templates/serviceaccount.yaml`
- `templates/secrets.yaml`
- `templates/configmap.yaml`
- `templates/ingress.yaml`
- `templates/networkpolicy.yaml`
- `templates/poddisruptionbudget.yaml`
- All files from `templates/elasticsearch/`
- All files from `templates/mariadb/`
- All files from `templates/redis/`
- All files from `templates/perceval/`
- All files from `templates/arthur/`
- All files from `templates/graal/`
- All files from `templates/sortinghat/`
- All files from `templates/sigils/`
- All files from `templates/kibiter/`

**Script Files:**
- `scripts/setup-local.sh`
- `scripts/deploy.sh`
- `scripts/cleanup.sh`
- `scripts/setup-replit.sh`
- `scripts/deploy-local-replit.sh`
- `scripts/demo-deployment.sh`

**Documentation:**
- `docs/README.md`
- `docs/DEPLOYMENT.md`
- `docs/TROUBLESHOOTING.md`

**Interactive Demo:**
- `interactive-demo/app.py`
- `interactive-demo/templates/dashboard.html`
- `interactive-demo/templates/perceval.html`
- `interactive-demo/templates/arthur.html`
- `interactive-demo/templates/kibiter.html`

### Method 2: Archive Creation

If you can create a ZIP/TAR archive from this environment:

```bash
# Create archive of the entire project
tar -czf grimoirelab-helm.tar.gz \
  Chart.yaml \
  values*.yaml \
  README.md \
  INSTALLATION_GUIDE.md \
  templates/ \
  scripts/ \
  docs/ \
  interactive-demo/ \
  output/

# Or create ZIP
zip -r grimoirelab-helm.zip \
  Chart.yaml \
  values*.yaml \
  README.md \
  INSTALLATION_GUIDE.md \
  templates/ \
  scripts/ \
  docs/ \
  interactive-demo/ \
  output/
```

## Quick Start After Download

1. **Set Permissions**
   ```bash
   chmod +x scripts/*.sh
   chmod +x interactive-demo/app.py
   ```

2. **Test Interactive Demo**
   ```bash
   cd interactive-demo/
   pip install flask
   python app.py
   # Visit http://localhost:5000
   ```

3. **Deploy to Kubernetes**
   ```bash
   # Install prerequisites (kubectl, helm, kind)
   # See INSTALLATION_GUIDE.md for details
   
   # Quick deployment
   ./scripts/setup-local.sh
   ```

4. **Validate Chart**
   ```bash
   helm lint . --values values-local.yaml
   ```

## File Manifest

**Total Files:** 47 files across the project structure

**Key Components:**
- 35 Kubernetes manifest templates
- 6 deployment scripts
- 4 HTML templates for demo
- 3 documentation files
- 3 configuration files

**Size:** Approximately 150KB total

## Prerequisites

- Kubernetes cluster or kind/minikube
- Helm 3.x
- kubectl
- Python 3.7+ (for demo)
- Docker (for local clusters)

## Support

After downloading, refer to:
- `README.md` - Project overview
- `INSTALLATION_GUIDE.md` - Detailed setup
- `docs/TROUBLESHOOTING.md` - Common issues
- Interactive demo at `http://localhost:5000` after running `python interactive-demo/app.py`