#!/bin/bash
set -e

ENV=$1
if [ -z "$ENV" ]; then
  echo "Usage: $0 <env> (dev or prod)"
  exit 1
fi

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/gist-api -n gist-api-$ENV

# Check pods
echo "Checking pod status..."
kubectl get pods -n gist-api-$ENV

# Check pod logs
echo "Checking pod logs..."
kubectl logs -n gist-api-$ENV deployment/gist-api --tail=10

# Check service
echo "Checking service..."
kubectl get svc -n gist-api-$ENV

# Get pod name
POD_NAME=$(kubectl get pod -n gist-api-$ENV -l app=gist-api -o jsonpath='{.items[0].metadata.name}')
echo "Testing API from within the pod: $POD_NAME"

# Test endpoint from within the pod itself (localhost)
echo "Testing API on localhost from within pod..."
if kubectl exec -n gist-api-$ENV $POD_NAME -- curl -f --max-time 5 http://localhost:8080/octocat; then
  echo ""
  echo "✓ Pod is responding on localhost"
else
  echo "✗ Pod not responding on localhost"
  exit 1
fi

# Test via service from within another pod
echo ""
echo "Testing API via service from within cluster..."
SERVICE_IP=$(kubectl get svc gist-api-service -n gist-api-$ENV -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SERVICE_IP"

if kubectl exec -n gist-api-$ENV $POD_NAME -- curl -f --max-time 5 http://gist-api-service:8080/octocat; then
  echo ""
  echo "✓ Validation complete - API is responding via service"
  exit 0
else
  echo "✗ Service not responding"
  exit 1
fi
