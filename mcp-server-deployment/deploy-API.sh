set -e

RESOURCE_GROUP="${RESOURCE_GROUP:-mcp-rg}"
APIM_NAME="${1}"
BACKEND_URL="${2}"
API_ID="playwright-mcp-server-api"

if [ -z "$APIM_NAME" ] || [ -z "$BACKEND_URL" ]; then
    echo "Error: APIM_NAME and BACKEND_URL are required" >&2
    exit 1
fi

if [[ "$BACKEND_URL" =~ ^\{ ]]; then
    echo "Detected JSON input, extracting FQDN..." >&2
    FQDN=$(echo "$BACKEND_URL" | grep -o '"fqdn": "[^"]*"' | sed 's/"fqdn": "\([^"]*\)"/\1/')
    if [ -z "$FQDN" ]; then
        echo "Error: Could not extract FQDN from JSON input" >&2
        exit 1
    fi
    BACKEND_URL="https://$FQDN"
    echo "Extracted FQDN: $FQDN" >&2
elif [[ ! "$BACKEND_URL" =~ ^https?:// ]]; then
    BACKEND_URL="https://$BACKEND_URL"
fi

echo "Creating API with backend URL: $BACKEND_URL" >&2

if [[ "$BACKEND_URL" =~ \[.*\] ]]; then
    echo "Error: IPv6 URLs are not supported. Backend URL: $BACKEND_URL" >&2
    exit 1
fi

EXISTING_API=$(az apim api show \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --api-id "$API_ID" \
    --query "name" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_API" ] && [ "$EXISTING_API" != "null" ]; then
    echo "Deleting existing API: $API_ID" >&2
    az apim api delete \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$API_ID" \
        --delete-revisions true \
        --yes
fi

az apim api create \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --api-id "$API_ID" \
    --display-name "MCP API" \
    --path "mcp" \
    --protocols https \
    --service-url "$BACKEND_URL" \
    --subscription-required true

# Create the SSE endpoint operation
az apim api operation create \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --api-id "$API_ID" \
    --operation-id "mcp-sse" \
    --display-name "MCP SSE Endpoint" \
    --method "GET" \
    --url-template "/sse" \
    --description "Server-Sent Events endpoint for MCP Server"

# Create the message endpoint operation
az apim api operation create \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --api-id "$API_ID" \
    --operation-id "mcp-message" \
    --display-name "MCP Message Endpoint" \
    --method "POST" \
    --url-template "/message" \
    --description "Message endpoint for MCP Server"

# Create the streamable HTTP GET endpoint operation
az apim api operation create \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --api-id "$API_ID" \
    --operation-id "mcp-streamable-http-get" \
    --display-name "MCP Streamable HTTP GET Endpoint" \
    --method "GET" \
    --url-template "/" \
    --description "Streamable HTTP GET endpoint for MCP Server"

# Create the streamable HTTP POST endpoint operation
az apim api operation create \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --api-id "$API_ID" \
    --operation-id "mcp-streamable-http-post" \
    --display-name "MCP Streamable HTTP POST Endpoint" \
    --method "POST" \
    --url-template "/" \
    --description "Streamable HTTP POST endpoint for MCP Server"

echo "API created successfully with subscription key required" >&2
echo "API ID: $API_ID" >&2
echo "API Path: /mcp" >&2
echo "Endpoints created:" >&2
echo "  - GET /mcp/sse (SSE endpoint)" >&2
echo "  - POST /mcp/message (Message endpoint)" >&2
echo "  - GET /mcp/ (Streamable HTTP GET)" >&2
echo "  - POST /mcp/ (Streamable HTTP POST)" >&2
echo "Note: Subscription key is required for API access" >&2