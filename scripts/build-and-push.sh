#!/bin/bash

# Simple script to build and push the frontend image
# Run this from the project root directory

set -e

echo "🔧 Building and pushing frontend image..."

# Set variables
ECR_REPO="581797537505.dkr.ecr.us-east-1.amazonaws.com/devops-cluster-frontend"
AWS_REGION="us-east-1"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Ensure we're in the right directory
if [ ! -f "application/frontend/Dockerfile" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    echo "Expected to find: application/frontend/Dockerfile"
    exit 1
fi

# Build the image
echo "🐳 Building Docker image..."
cd application/frontend
docker build -t frontend-nginx-fix:latest .
cd ../..

# Tag for ECR
echo "🏷️  Tagging image for ECR..."
docker tag frontend-nginx-fix:latest $ECR_REPO:latest
docker tag frontend-nginx-fix:latest $ECR_REPO:$TIMESTAMP

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin 581797537505.dkr.ecr.us-east-1.amazonaws.com

# Push images
echo "📤 Pushing images to ECR..."
docker push $ECR_REPO:latest
docker push $ECR_REPO:$TIMESTAMP

echo "✅ Build and push completed!"
echo "📋 Images pushed:"
echo "  - $ECR_REPO:latest"
echo "  - $ECR_REPO:$TIMESTAMP"
echo ""
echo "🚀 Next steps:"
echo "1. Apply Kubernetes manifests:"
echo "   kubectl apply -f k8s-manifests/configmaps/app-config.yaml"
echo "   kubectl apply -f k8s-manifests/deployments/frontend-deployment.yaml"
echo ""
echo "2. Restart deployment:"
echo "   kubectl rollout restart deployment/frontend -n devops-app"
echo "   kubectl rollout status deployment/frontend -n devops-app"