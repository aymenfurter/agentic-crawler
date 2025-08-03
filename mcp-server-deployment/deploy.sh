set -e

export RESOURCE_GROUP="${RESOURCE_GROUP:-mcp-rg}"
export LOCATION="${LOCATION:-eastus}"

echo "Starting deployment..."
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"

echo "Deploying API Management..."
APIM_IP=$(./deploy-apim.sh)
if [ -z "$APIM_IP" ]; then
    echo "Error: Failed to get APIM IP address" >&2
    exit 1
fi

export APIM_NAME=$(az apim list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -z "$APIM_NAME" ] || [ "$APIM_NAME" = "null" ]; then
    echo "Error: Failed to get APIM name" >&2
    exit 1
fi

echo "APIM_NAME: $APIM_NAME"
echo "APIM_IP: $APIM_IP"

echo "Deploying Container App..."
CONTAINER_URL=$(./deploy-container.sh "$APIM_IP")
if [ -z "$CONTAINER_URL" ]; then
    echo "Error: Failed to get Container URL" >&2
    exit 1
fi

CONTAINER_URL=$(echo "$CONTAINER_URL" | sed 's/\/mcp$//' | sed 's/\/$//')

# To Be Removed?`
BACKEND_URL="https://$CONTAINER_URL"

echo "Container URL: https://$CONTAINER_URL" 
echo "Backend URL: $BACKEND_URL"

# Deploy API
echo "Deploying API..."
./deploy-API.sh "$APIM_NAME" "$BACKEND_URL"

APIM_GATEWAY_URL=$(az apim show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APIM_NAME" \
    --query "gatewayUrl" -o tsv)

if [[ ! "$APIM_GATEWAY_URL" =~ /$ ]]; then
    APIM_GATEWAY_URL="${APIM_GATEWAY_URL}/"
fi

cat > mcp-config.json <<EOF
{
  "mcpServers": {
    "playwright": {
      "url": "${APIM_GATEWAY_URL}mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "YOUR_SUBSCRIPTION_KEY_HERE"
      }
    }
  }
}
EOF

echo "Deployment completed successfully!"
echo "MCP_ENDPOINT=${APIM_GATEWAY_URL}mcp"
echo ""
echo "API deployed with subscription protection enabled."
echo "To get a subscription key:"
echo "1. Go to Azure Portal > API Management > $APIM_NAME > Subscriptions"
echo "2. Create a new subscription or use an existing one"
echo "3. Copy the subscription key and replace 'YOUR_SUBSCRIPTION_KEY_HERE' in mcp-config.json"
echo ""
echo "Configuration saved to mcp-config.json"