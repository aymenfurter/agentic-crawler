set -e

RESOURCE_GROUP="${RESOURCE_GROUP:-mcp-rg}"
LOCATION="${LOCATION:-eastus}"
APP_NAME="${APP_NAME:-playwright-mcp-server}"
APIM_IP="${1}"

EXISTING_ENV=$(az containerapp env list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?contains(name, 'playwright-mcp-server')].name | [0]" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_ENV" ]; then
    echo "Using existing Container App Environment: $EXISTING_ENV" >&2
    ENV_NAME="$EXISTING_ENV"
else
    ENV_NAME="${APP_NAME}-env"
    
    EXISTING_WORKSPACE=$(az monitor log-analytics workspace list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[0]" 2>/dev/null || echo "")

    if [ -n "$EXISTING_WORKSPACE" ] && [ "$EXISTING_WORKSPACE" != "null" ]; then
        WORKSPACE_NAME=$(echo "$EXISTING_WORKSPACE" | jq -r '.name')
        EXISTING_WORKSPACE_ID=$(echo "$EXISTING_WORKSPACE" | jq -r '.customerId')
        
        if [[ "$EXISTING_WORKSPACE_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
            echo "Using existing Log Analytics workspace: $WORKSPACE_NAME" >&2
            WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
                --resource-group "$RESOURCE_GROUP" \
                --workspace-name "$WORKSPACE_NAME" \
                --query "primarySharedKey" -o tsv)
            WORKSPACE_ARGS="--logs-workspace-id $EXISTING_WORKSPACE_ID --logs-workspace-key $WORKSPACE_KEY"
        else
            echo "Existing workspace ID is not in valid GUID format, will create new one" >&2
            WORKSPACE_ARGS=""
        fi
    else
        echo "No existing Log Analytics workspace found, will create new one" >&2
        WORKSPACE_ARGS=""
    fi


    az containerapp env create \
        --name "$ENV_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        $WORKSPACE_ARGS
fi

EXISTING_APP=$(az containerapp list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?name=='$APP_NAME'].name | [0]" -o tsv 2>/dev/null || echo "")

if [ -z "$EXISTING_APP" ]; then
    az containerapp create \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --environment "$ENV_NAME" \
        --image "mcr.microsoft.com/playwright/mcp:latest" \
        --target-port 8080 \
        --ingress external \
        --min-replicas 1 \
        --command "node, cli.js, --headless, --browser, chromium, --no-sandbox, --port, 8080, --host, 0.0.0.0" \
        --max-replicas 1 \
        --cpu 4.0 \
        --memory 8.0Gi
else
    echo "Container app $APP_NAME already exists, skipping creation" >&2
fi

if [ -n "$APIM_IP" ]; then
    az containerapp ingress access-restriction set \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --rule-name "allow-apim" \
        --ip-address "$APIM_IP/32" \
        --action Allow >&2
fi

CONTAINER_URL=$(az containerapp show \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.configuration.ingress.fqdn" -o tsv)

if [ -z "$CONTAINER_URL" ] || [ "$CONTAINER_URL" = "null" ]; then
    echo "Error: Failed to get container app FQDN" >&2
    exit 1
fi

echo "$CONTAINER_URL"