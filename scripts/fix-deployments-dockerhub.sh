#!/bin/bash

set -e

echo "🔧 Fixing Kubernetes deployment issues with Docker Hub..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
DOCKER_USERNAME="mohitsgowda"
NAMESPACE="devops-app"

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "docker is not installed or not in PATH"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    print_warning "Namespace $NAMESPACE does not exist. Creating it..."
    kubectl create namespace $NAMESPACE
fi

print_step "Cleaning up existing failed deployments..."
kubectl delete deployment frontend user-service -n $NAMESPACE --ignore-not-found=true

print_status "Waiting for pods to terminate..."
sleep 10

print_step "Building and tagging frontend image..."
cd application/frontend
docker build -t $DOCKER_USERNAME/devops-frontend:latest .
print_status "Frontend image built successfully"
cd ../..

print_step "Building and tagging user-service image..."
cd application/backend/user-service
docker build -t $DOCKER_USERNAME/devops-user-service:latest .
print_status "User-service image built successfully"
cd ../../..

print_warning "Images built locally. To push to Docker Hub, run:"
echo "docker login"
echo "docker push $DOCKER_USERNAME/devops-frontend:latest"
echo "docker push $DOCKER_USERNAME/devops-user-service:latest"
echo ""

print_step "Applying ConfigMaps..."
kubectl apply -f k8s-manifests/configmaps/app-config.yaml

print_step "Applying updated deployments..."
kubectl apply -f k8s-manifests/deployments/frontend-deployment.yaml
kubectl apply -f k8s-manifests/deployments/user-service-deployment.yaml

print_step "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n $NAMESPACE || true
kubectl wait --for=condition=available --timeout=300s deployment/user-service -n $NAMESPACE || true

print_step "Checking final pod status..."
kubectl get pods -n $NAMESPACE

print_status "Deployment fix completed! ✅"

echo ""
echo "To monitor the deployments:"
echo "kubectl get pods -n $NAMESPACE -w"
echo ""
echo "To check logs:"
echo "kubectl logs -f deployment/frontend -n $NAMESPACE"
echo "kubectl logs -f deployment/user-service -n $NAMESPACE"
echo ""
echo "To test the services:"
echo "kubectl port-forward -n $NAMESPACE svc/frontend 8080:80"
echo "kubectl port-forward -n $NAMESPACE svc/user-service 3001:3001"
echo ""
echo "If images need to be pushed to Docker Hub:"
echo "docker login && docker push $DOCKER_USERNAME/devops-frontend:latest && docker push $DOCKER_USERNAME/devops-user-service:latest"