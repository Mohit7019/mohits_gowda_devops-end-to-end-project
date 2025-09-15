#!/bin/bash

# Script to fix and redeploy the frontend with nginx permission fixes
# This script addresses the nginx permission denied error for /run/nginx.pid

set -e

echo "🔧 Starting frontend deployment fix..."

# Set variables
PROJECT_DIR="/Users/mohitsrinivasappa/Project/mohits_gowda_devops-end-to-end-project"
ECR_REPO="581797537505.dkr.ecr.us-east-1.amazonaws.com/devops-cluster-frontend"
AWS_REGION="us-east-1"
NAMESPACE="devops-app"

# Change to project directory
cd "$PROJECT_DIR"

echo "📍 Current directory: $(pwd)"

# Step 1: Build the new Docker image with nginx permission fixes
echo "🐳 Building Docker image with nginx permission fixes..."
cd application/frontend
docker build -t frontend-fixed:latest .

# Step 2: Tag the image for ECR
echo "🏷️  Tagging image for ECR..."
docker tag frontend-fixed:latest $ECR_REPO:latest
docker tag frontend-fixed:latest $ECR_REPO:$(date +%Y%m%d-%H%M%S)

# Step 3: Login to ECR and push the image
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

echo "📤 Pushing image to ECR..."
docker push $ECR_REPO:latest
docker push $ECR_REPO:$(date +%Y%m%d-%H%M%S)

# Step 4: Apply the updated Kubernetes manifests
echo "☸️  Applying updated Kubernetes manifests..."
cd "$PROJECT_DIR"

# Apply configmap first
kubectl apply -f k8s-manifests/configmaps/app-config.yaml

# Apply the updated deployment
kubectl apply -f k8s-manifests/deployments/frontend-deployment.yaml

# Step 5: Restart the deployment to pick up the new image
echo "🔄 Restarting frontend deployment..."
kubectl rollout restart deployment/frontend -n $NAMESPACE

# Step 6: Wait for rollout to complete
echo "⏳ Waiting for rollout to complete..."
kubectl rollout status deployment/frontend -n $NAMESPACE --timeout=300s

# Step 7: Check pod status
echo "📊 Checking pod status..."
kubectl get pods -n $NAMESPACE -l app=frontend

# Step 8: Show recent logs
echo "📋 Recent logs from frontend pods:"
kubectl logs -n $NAMESPACE -l app=frontend --tail=20

echo "✅ Frontend deployment fix completed!"
echo ""
echo "🔍 To monitor the pods:"
echo "kubectl get pods -n $NAMESPACE -l app=frontend -w"
echo ""
echo "📋 To check logs:"
echo "kubectl logs -n $NAMESPACE -l app=frontend -f"
echo ""
echo "🌐 To test the health endpoint:"
echo "kubectl port-forward -n $NAMESPACE svc/frontend 8080:80"
echo "Then visit: http://localhost:8080/health"