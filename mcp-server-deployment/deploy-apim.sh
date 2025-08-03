set -e

RESOURCE_GROUP="${RESOURCE_GROUP:-mcp-rg}"
LOCATION="${LOCATION:-eastus}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" &>/dev/null || true

EXISTING_APIM=$(az apim list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$EXISTING_APIM" ] || [ "$EXISTING_APIM" = "null" ]; then
    APIM_NAME="${APIM_NAME:-mcp-apim-$(date +%s)}"
    
    echo "Creating new APIM instance: $APIM_NAME" >&2
    az apim create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APIM_NAME" \
        --location "$LOCATION" \
        --publisher-name "MCP" \
        --publisher-email "admin@mcp.local" \
        --sku-name Developer \
        --sku-capacity 1
else
    APIM_NAME="$EXISTING_APIM"
    echo "Using existing APIM instance: $APIM_NAME" >&2
fi

echo "Waiting for APIM to be ready..." >&2
az apim wait --created --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --timeout 1200

for i in {1..30}; do
    APIM_STATE=$(az apim show --resource-group "$RESOURCE_GROUP" --name "$APIM_NAME" --query "provisioningState" -o tsv 2>/dev/null || echo "Unknown")
    if [ "$APIM_STATE" = "Succeeded" ]; then
        echo "APIM is fully operational" >&2
        break
    fi
    echo "APIM state: $APIM_STATE, waiting..." >&2
    sleep 30
done

APIM_PUBLIC_IP=$(az apim show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APIM_NAME" \
    --query "publicIpAddresses" -o tsv)

if [ -z "$APIM_PUBLIC_IP" ]; then
    echo "Error: Could not retrieve APIM public IP" >&2
    exit 1
fi

echo "$APIM_PUBLIC_IP"