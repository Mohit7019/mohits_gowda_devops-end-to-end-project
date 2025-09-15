# Nginx Permission Issue Fix

## Problem Description

The frontend pod was failing to start with the following error:
```
2025/09/15 05:35:43 [emerg] 1#1: open() "/run/nginx.pid" failed (13: Permission denied)
nginx: [emerg] open() "/run/nginx.pid" failed (13: Permission denied)
```

## Root Cause Analysis

The issue occurred because:

1. **Security Context**: The Kubernetes deployment was configured to run as a non-root user (UID 101) with `runAsNonRoot: true`
2. **Nginx Default Behavior**: The standard nginx Docker image expects to run as root and write to system directories like `/run/nginx.pid`
3. **Permission Mismatch**: The non-root user (nginx, UID 101) didn't have write permissions to `/run/nginx.pid`

## Solution Applied

### 1. Dockerfile Changes (`application/frontend/Dockerfile`)

**Key Modifications:**
- Created proper nginx user with UID 101 to match Kubernetes security context
- Set up directories with correct ownership and permissions:
  - `/var/cache/nginx`
  - `/var/log/nginx` 
  - `/var/run`
- Created custom nginx.conf that works with non-root user
- Changed ownership of all nginx-related files to nginx user
- Switched to nginx user before starting the service

**Critical Changes:**
```dockerfile
# Create nginx user and set up directories with proper permissions
RUN addgroup -g 101 -S nginx && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx && \
    mkdir -p /var/cache/nginx /var/log/nginx /var/run && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/run && \
    chmod -R 755 /var/cache/nginx /var/log/nginx /var/run && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid

# Switch to nginx user
USER nginx
```

### 2. Kubernetes Deployment Changes (`k8s-manifests/deployments/frontend-deployment.yaml`)

**Enhanced Security Context:**
- Added `runAsGroup: 101` to match the nginx group
- Added `readOnlyRootFilesystem: false` to allow nginx to write to necessary directories
- Added capability dropping for enhanced security
- Added volume mount for `/var/run` directory

**Key Changes:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 101
  runAsGroup: 101
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  capabilities:
    drop:
    - ALL
volumeMounts:
- name: nginx-run
  mountPath: /var/run
volumes:
- name: nginx-run
  emptyDir:
    sizeLimit: 10Mi
```

## Files Modified

1. **`application/frontend/Dockerfile`**
   - Added proper user setup and permissions
   - Created custom nginx configuration
   - Switched to non-root user

2. **`k8s-manifests/deployments/frontend-deployment.yaml`**
   - Enhanced security context
   - Added volume mount for `/var/run`
   - Improved security with capability dropping

3. **`scripts/fix-frontend-deployment.sh`** (New)
   - Automated deployment script
   - Handles Docker build, ECR push, and Kubernetes deployment

## Deployment Instructions

### Option 1: Automated Script (Full Deployment)
```bash
cd /Users/mohitsrinivasappa/Project/mohits_gowda_devops-end-to-end-project
./scripts/fix-frontend-deployment.sh
```

### Option 2: Build and Push Only
```bash
cd /Users/mohitsrinivasappa/Project/mohits_gowda_devops-end-to-end-project
./scripts/build-and-push.sh
```

### Option 3: Manual Steps
```bash
# 1. Navigate to project root
cd /Users/mohitsrinivasappa/Project/mohits_gowda_devops-end-to-end-project

# 2. Build Docker image (ensure you're in project root)
cd application/frontend
docker build -t frontend-nginx-fix:latest .
cd ../..

# 3. Tag and push to ECR
docker tag frontend-nginx-fix:latest 581797537505.dkr.ecr.us-east-1.amazonaws.com/devops-cluster-frontend:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 581797537505.dkr.ecr.us-east-1.amazonaws.com
docker push 581797537505.dkr.ecr.us-east-1.amazonaws.com/devops-cluster-frontend:latest

# 4. Apply Kubernetes manifests
kubectl apply -f k8s-manifests/configmaps/app-config.yaml
kubectl apply -f k8s-manifests/deployments/frontend-deployment.yaml

# 5. Restart deployment
kubectl rollout restart deployment/frontend -n devops-app
kubectl rollout status deployment/frontend -n devops-app
```

### Docker Build Troubleshooting

If you encounter `"docker buildx build" requires exactly 1 argument` error:

1. **Ensure you're in the correct directory**: The build context (`.`) must be specified
2. **Check Docker version**: Run `docker --version` to ensure Docker is properly installed
3. **Try alternative build command**:
   ```bash
   cd application/frontend
   docker build --tag frontend-nginx-fix:latest .
   ```
4. **If using Docker Desktop**: Ensure it's running and updated to the latest version

## Verification

After deployment, verify the fix:

```bash
# Check pod status
kubectl get pods -n devops-app -l app=frontend

# Check logs (should show successful nginx startup)
kubectl logs -n devops-app -l app=frontend

# Test health endpoint
kubectl port-forward -n devops-app svc/frontend 8080:80
curl http://localhost:8080/health
```

## Expected Results

- ✅ Nginx starts successfully without permission errors
- ✅ Pod reaches Running state
- ✅ Health checks pass
- ✅ Application serves content on port 8080

## Security Benefits

1. **Non-root execution**: Maintains security by running as non-root user
2. **Minimal privileges**: Drops all capabilities except necessary ones
3. **Isolated volumes**: Uses emptyDir volumes for writable directories
4. **Read-only filesystem**: Can be enabled in future for enhanced security

## Troubleshooting

If issues persist:

1. **Check pod events**: `kubectl describe pod <pod-name> -n devops-app`
2. **Verify user ID**: `kubectl exec -it <pod-name> -n devops-app -- id`
3. **Check file permissions**: `kubectl exec -it <pod-name> -n devops-app -- ls -la /var/run/`
4. **Monitor logs**: `kubectl logs -f <pod-name> -n devops-app`

## References

- [Nginx Docker Official Documentation](https://hub.docker.com/_/nginx)
- [Kubernetes Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Running Nginx as Non-Root User](https://www.nginx.com/blog/running-nginx-as-a-non-root-user/)