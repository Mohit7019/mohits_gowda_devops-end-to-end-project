#!/bin/bash

set -e

echo "🔧 Fixing all Kubernetes deployment issues..."

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
ECR_REGISTRY="581797537505.dkr.ecr.us-east-1.amazonaws.com"
AWS_REGION="us-east-1"
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

if ! command -v aws &> /dev/null; then
    print_error "aws CLI is not installed or not in PATH"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    print_warning "Namespace $NAMESPACE does not exist. Creating it..."
    kubectl create namespace $NAMESPACE
fi

print_step "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

print_step "Cleaning up existing failed deployments..."
kubectl delete deployment frontend user-service -n $NAMESPACE --ignore-not-found=true

print_status "Waiting for pods to terminate..."
sleep 10

print_step "Building and pushing frontend image..."
cd application/frontend
docker build -t frontend-fixed:latest .
docker tag frontend-fixed:latest $ECR_REGISTRY/devops-cluster-frontend:latest
docker push $ECR_REGISTRY/devops-cluster-frontend:latest
cd ../..

print_step "Building and pushing user-service image..."
cd application/backend/user-service
docker build -t user-service-fixed:latest .
docker tag user-service-fixed:latest $ECR_REGISTRY/devops-cluster-user-service:latest
docker push $ECR_REGISTRY/devops-cluster-user-service:latest
cd ../../..

print_step "Applying ConfigMaps..."
kubectl apply -f k8s-manifests/configmaps/app-config.yaml

print_step "Applying updated deployments..."
kubectl apply -f k8s-manifests/deployments/frontend-deployment.yaml
kubectl apply -f k8s-manifests/deployments/user-service-deployment.yaml

print_step "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/user-service -n $NAMESPACE

print_step "Checking final pod status..."
kubectl get pods -n $NAMESPACE

print_status "Deployment fix completed successfully! ✅"

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