# Kubernetes Deployment Fix Guide

## Issues Identified and Fixed

### 1. Frontend CrashLoopBackOff Issue
**Problem**: Nginx permission denied for `/run/nginx.pid`
**Root Cause**: Non-root user (UID 101) couldn't write to system directories

**Solution Applied**:
- Updated [`Dockerfile`](application/frontend/Dockerfile) to properly set up nginx user permissions
- Created writable directories with correct ownership
- Modified nginx configuration to use `/var/run/nginx.pid`
- Added proper volume mounts in deployment

### 2. User-service ImagePullBackOff Issue
**Problem**: ECR images not found and permission issues
**Root Cause**: 
- ECR repositories didn't exist
- Account ID mismatch (581797537505 vs 906691051131)
- Insufficient ECR permissions

**Solution Applied**:
- Switched from ECR to Docker Hub registry
- Updated deployment configurations to use `mohitsgowda/devops-*:latest` images
- Fixed user-service Dockerfile to use `npm install` instead of `npm ci`

## Files Modified

### 1. Frontend Application
- **[`application/frontend/Dockerfile`](application/frontend/Dockerfile)**
  - Fixed nginx user permissions
  - Added proper directory setup
  - Removed conflicting user creation

### 2. User-service Application  
- **[`application/backend/user-service/Dockerfile`](application/backend/user-service/Dockerfile)**
  - Changed from `npm ci` to `npm install` (no package-lock.json)
  - Maintained security best practices

### 3. Kubernetes Deployments
- **[`k8s-manifests/deployments/frontend-deployment.yaml`](k8s-manifests/deployments/frontend-deployment.yaml)**
  - Updated image to `mohitsgowda/devops-frontend:latest`
  - Maintained security context and volume mounts

- **[`k8s-manifests/deployments/user-service-deployment.yaml`](k8s-manifests/deployments/user-service-deployment.yaml)**
  - Updated image to `mohitsgowda/devops-user-service:latest`
  - Kept health checks and resource limits

### 4. Fix Scripts
- **[`scripts/fix-deployments-dockerhub.sh`](scripts/fix-deployments-dockerhub.sh)**
  - Comprehensive deployment fix script
  - Builds images locally and provides push instructions

## Deployment Instructions

### Option 1: Complete Automated Fix (Recommended)
```bash
cd /Users/mohitsrinivasappa/Project/mohits_gowda_devops-end-to-end-project
./scripts/fix-deployments-dockerhub.sh
```

### Option 2: Manual Step-by-Step

#### Step 1: Build Images Locally
```bash
# Build frontend image
cd application/frontend
docker build -t mohitsgowda/devops-frontend:latest .

# Build user-service image  
cd ../backend/user-service
docker build -t mohitsgowda/devops-user-service:latest .
cd ../../..
```

#### Step 2: Push to Docker Hub (Optional)
```bash
# Login to Docker Hub
docker login

# Push images
docker push mohitsgowda/devops-frontend:latest
docker push mohitsgowda/devops-user-service:latest
```

#### Step 3: Deploy to Kubernetes
```bash
# Apply configurations
kubectl apply -f k8s-manifests/configmaps/app-config.yaml
kubectl apply -f k8s-manifests/deployments/frontend-deployment.yaml
kubectl apply -f k8s-manifests/deployments/user-service-deployment.yaml

# Wait for deployments
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n devops-app
kubectl wait --for=condition=available --timeout=300s deployment/user-service -n devops-app
```

## Verification Steps

### 1. Check Pod Status
```bash
kubectl get pods -n devops-app
```
Expected: All pods should be in `Running` state

### 2. Check Logs
```bash
# Frontend logs
kubectl logs -f deployment/frontend -n devops-app

# User-service logs  
kubectl logs -f deployment/user-service -n devops-app
```

### 3. Test Services
```bash
# Test frontend
kubectl port-forward -n devops-app svc/frontend 8080:80
curl http://localhost:8080/health

# Test user-service
kubectl port-forward -n devops-app svc/user-service 3001:3001  
curl http://localhost:3001/health
```

## Current Status

✅ **Fixed Issues**:
- Frontend nginx permission problems
- ECR repository and authentication issues
- User-service Docker build problems
- Deployment configuration updates

⚠️ **Remaining Steps**:
- Images need to be pushed to Docker Hub for public access
- Alternative: Use local Docker registry or different image registry

## Troubleshooting

### If Pods Still Show ImagePullBackOff
1. **Check if images exist locally**:
   ```bash
   docker images | grep mohitsgowda
   ```

2. **Push images to Docker Hub**:
   ```bash
   docker login
   docker push mohitsgowda/devops-frontend:latest
   docker push mohitsgowda/devops-user-service:latest
   ```

3. **Or use imagePullPolicy: Never for local testing**:
   ```yaml
   spec:
     containers:
     - name: frontend
       image: mohitsgowda/devops-frontend:latest
       imagePullPolicy: Never  # Add this line
   ```

### If Frontend Still Crashes
1. **Check nginx logs**:
   ```bash
   kubectl logs <frontend-pod-name> -n devops-app
   ```

2. **Verify volume mounts**:
   ```bash
   kubectl describe pod <frontend-pod-name> -n devops-app
   ```

### If User-service Fails to Start
1. **Check application logs**:
   ```bash
   kubectl logs <user-service-pod-name> -n devops-app
   ```

2. **Verify health endpoint**:
   ```bash
   kubectl exec -it <user-service-pod-name> -n devops-app -- wget -qO- http://localhost:3001/health
   ```

## Security Improvements Applied

1. **Non-root execution**: Both containers run as non-root users
2. **Minimal privileges**: Dropped all unnecessary capabilities  
3. **Read-only filesystem**: Where possible (user-service)
4. **Resource limits**: CPU and memory constraints applied
5. **Health checks**: Liveness and readiness probes configured

## Next Steps

1. **Push images to registry** for production deployment
2. **Set up CI/CD pipeline** for automated builds and deployments
3. **Configure monitoring** and logging for the applications
4. **Implement proper secrets management** for sensitive data
5. **Add ingress controller** for external access

## Support

If you encounter issues:
1. Check the pod events: `kubectl describe pod <pod-name> -n devops-app`
2. Review application logs: `kubectl logs <pod-name> -n devops-app`
3. Verify network connectivity and DNS resolution
4. Ensure all required ConfigMaps and Secrets exist