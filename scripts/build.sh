#!/bin/bash
set -e

# Build Docker image
docker build -t gist-api -f docker/Dockerfile .

# Get ECR repo URL from Terraform output
cd terraform
ECR_REPO=$(terraform output -raw ecr_repository_url)
cd ..

echo "DEBUG: ECR_REPO = $ECR_REPO"

# Extract registry URL (remove repository name for docker login)
ECR_REGISTRY=$(echo $ECR_REPO | cut -d'/' -f1)

echo "DEBUG: ECR_REGISTRY = $ECR_REGISTRY"

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

# Tag and push
docker tag gist-api:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

echo "Image pushed to $ECR_REPO:latest"
