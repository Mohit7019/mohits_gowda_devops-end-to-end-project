#!/bin/bash

set -e

echo "🔧 Fixing Kubernetes deployments with public images..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

NAMESPACE="devops-app"

print_step "Cleaning up existing deployments..."
kubectl delete deployment frontend user-service -n $NAMESPACE --ignore-not-found=true

print_status "Waiting for pods to terminate..."
sleep 10

print_step "Creating temporary deployments with public images..."

# Create a simple frontend deployment using nginx
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: devops-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
        - name: html-content
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: nginx-config
        configMap:
          name: frontend-config
      - name: html-content
        configMap:
          name: frontend-html
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: devops-app
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: frontend
EOF

# Create a simple user-service deployment using node
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: devops-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: node:18-alpine
        command: ["node", "-e"]
        args:
        - |
          const express = require('express');
          const app = express();
          const PORT = 3001;
          
          app.use(express.json());
          
          app.get('/health', (req, res) => {
            res.json({ status: 'healthy', timestamp: new Date().toISOString() });
          });
          
          app.get('/users', (req, res) => {
            res.json({ 
              success: true, 
              data: [
                { id: 1, name: 'John Doe', email: 'john@example.com' },
                { id: 2, name: 'Jane Smith', email: 'jane@example.com' }
              ]
            });
          });
          
          app.listen(PORT, () => {
            console.log(\`User service running on port \${PORT}\`);
          });
        ports:
        - containerPort: 3001
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: devops-app
spec:
  type: ClusterIP
  ports:
  - port: 3001
    targetPort: 3001
    protocol: TCP
  selector:
    app: user-service
EOF

# Create ConfigMaps for frontend
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: devops-app
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files \$uri \$uri/ /index.html;
        }
        
        location /api/ {
            proxy_pass http://user-service:3001/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-html
  namespace: devops-app
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>DevOps Demo App</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 800px; margin: 0 auto; }
            .status { padding: 20px; background: #e8f5e8; border-radius: 5px; margin: 20px 0; }
            .error { background: #ffe8e8; }
            button { padding: 10px 20px; margin: 10px; cursor: pointer; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 DevOps Demo Application</h1>
            <div id="status" class="status">
                <h3>Application Status: ✅ Running</h3>
                <p>Frontend and User Service are operational!</p>
            </div>
            
            <h2>Test User Service</h2>
            <button onclick="testHealth()">Test Health Endpoint</button>
            <button onclick="getUsers()">Get Users</button>
            
            <div id="results"></div>
        </div>
        
        <script>
            async function testHealth() {
                try {
                    const response = await fetch('/api/health');
                    const data = await response.json();
                    document.getElementById('results').innerHTML = 
                        '<h3>Health Check Result:</h3><pre>' + JSON.stringify(data, null, 2) + '</pre>';
                } catch (error) {
                    document.getElementById('results').innerHTML = 
                        '<h3 class="error">Error:</h3><p>' + error.message + '</p>';
                }
            }
            
            async function getUsers() {
                try {
                    const response = await fetch('/api/users');
                    const data = await response.json();
                    document.getElementById('results').innerHTML = 
                        '<h3>Users:</h3><pre>' + JSON.stringify(data, null, 2) + '</pre>';
                } catch (error) {
                    document.getElementById('results').innerHTML = 
                        '<h3 class="error">Error:</h3><p>' + error.message + '</p>';
                }
            }
        </script>
    </body>
    </html>
EOF

print_step "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/user-service -n $NAMESPACE

print_step "Checking final pod status..."
kubectl get pods -n $NAMESPACE

print_status "Deployment completed successfully! ✅"

echo ""
echo "To test the application:"
echo "kubectl port-forward -n $NAMESPACE svc/frontend 8080:80"
echo "Then open: http://localhost:8080"
echo ""
echo "To check logs:"
echo "kubectl logs -f deployment/frontend -n $NAMESPACE"
echo "kubectl logs -f deployment/user-service -n $NAMESPACE"