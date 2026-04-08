#!/usr/bin/env bash
# Deploy Veyant Preference Engine to Azure Container Apps
# Prerequisites: az login, Docker installed, az containerapp extension
#
# Usage: ./scripts/deploy_container_apps.sh

set -e

# ── config ────────────────────────────────────────────────────────────────────
RESOURCE_GROUP="rg-veyant-dev-eastus2"
LOCATION="eastus2"
ENVIRONMENT="veyant-env"
APP_NAME="veyant-preference-api"
REGISTRY="veyantregistry"   # must be globally unique — change if taken
IMAGE="veyant-preference-api:latest"

# ── resource group ────────────────────────────────────────────────────────────
echo "Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# ── container registry ────────────────────────────────────────────────────────
echo "Creating container registry..."
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $REGISTRY \
  --sku Basic \
  --admin-enabled true

# Build and push image
echo "Building and pushing image..."
az acr build \
  --registry $REGISTRY \
  --image $IMAGE \
  --file api/Dockerfile \
  api/

# Get registry credentials
REGISTRY_SERVER=$(az acr show --name $REGISTRY --query loginServer -o tsv)
REGISTRY_USER=$(az acr credential show --name $REGISTRY --query username -o tsv)
REGISTRY_PASS=$(az acr credential show --name $REGISTRY --query passwords[0].value -o tsv)

# ── container apps environment ────────────────────────────────────────────────
echo "Creating Container Apps environment..."
az containerapp env create \
  --name $ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# ── deploy app ────────────────────────────────────────────────────────────────
echo "Deploying preference API..."
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT \
  --image "$REGISTRY_SERVER/$IMAGE" \
  --registry-server $REGISTRY_SERVER \
  --registry-username $REGISTRY_USER \
  --registry-password $REGISTRY_PASS \
  --target-port 8000 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 2 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --env-vars \
    OLLAMA_BASE_URL=http://localhost:11434 \
    OLLAMA_MODEL=llama3:8b

APP_URL=$(az containerapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn -o tsv)

echo ""
echo "Deployed! API available at: https://$APP_URL"
echo "Health check: https://$APP_URL/health"
