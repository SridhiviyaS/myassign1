#!/bin/bash
set -e

ENV=$1
if [ -z "$ENV" ]; then
  echo "Usage: $0 <env> (dev or prod)"
  exit 1
fi

echo "Deploying to $ENV environment..."

# Deploy using Kustomize
kubectl apply -k k8s/overlays/$ENV

echo "Successfully deployed to $ENV environment"

# Show deployment status
kubectl get pods -n gist-api-$ENV
