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

# Check service
echo "Checking service..."
kubectl get svc -n gist-api-$ENV

# Test endpoint
echo "Testing API endpoint..."
SERVICE_IP=$(kubectl get svc gist-api-service -n gist-api-$ENV -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SERVICE_IP"

# Try to curl the endpoint with timeout and retries
for i in {1..5}; do
  echo "Attempt $i to connect to API..."
  if curl -f --max-time 10 http://$SERVICE_IP:8080/octocat; then
    echo ""
    echo "✓ Validation complete - API is responding"
    exit 0
  fi
  echo "Retrying in 5 seconds..."
  sleep 5
done

echo "✗ Validation failed - API not responding after 5 attempts"
exit 1
