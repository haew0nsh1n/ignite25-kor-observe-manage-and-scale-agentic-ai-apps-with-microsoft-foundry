#!/bin/bash
# ============================================================================
# Script: 1-get-env-selfguided.sh
# Description: Interactive script to recreate .env file from Azure resources
#              Prompts for Azure login, auto-discovers rg-Ignite* resource groups,
#              and allows user to override the selection
# Usage: ./scripts/1-get-env-selfguided.sh
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$WORKSPACE_ROOT/.env"

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}    Azure Environment Setup - Self-Guided${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# ============================================================================
# Step 1: Verify Azure CLI installation
# ============================================================================
echo -e "${YELLOW}Step 1: Verifying Azure CLI installation...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}✗ Azure CLI is not installed${NC}"
    echo -e "${YELLOW}Please install Azure CLI:${NC}"
    echo -e "  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
echo -e "${GREEN}✓ Azure CLI installed (version: $AZ_VERSION)${NC}\n"

# ============================================================================
# Step 2: Check Azure CLI login status
# ============================================================================
echo -e "${YELLOW}Step 2: Checking Azure authentication...${NC}"

if ! az account show &>/dev/null; then
    echo -e "${CYAN}You need to log in to Azure.${NC}"
    echo -e "${CYAN}Press Enter to launch Azure login...${NC}"
    read -r
    
    echo -e "${YELLOW}Launching Azure login...${NC}"
    if ! az login; then
        echo -e "${RED}✗ Azure login failed${NC}"
        exit 1
    fi
    echo ""
fi

# Get current account information
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo -e "${GREEN}✓ Logged in to Azure${NC}"
echo -e "  ${BOLD}Subscription:${NC} $SUBSCRIPTION_NAME"
echo -e "  ${BOLD}Subscription ID:${NC} $AZURE_SUBSCRIPTION_ID"
echo -e "  ${BOLD}Tenant ID:${NC} $AZURE_TENANT_ID\n"

# ============================================================================
# Step 3: Auto-discover and prompt for Resource Group
# ============================================================================
echo -e "${YELLOW}Step 3: Discovering resource groups...${NC}"

# Find resource groups with rg-Ignite prefix
echo -e "${CYAN}Searching for resource groups with 'rg-Ignite' prefix...${NC}"

IGNITE_RGS=$(az group list --query "[?starts_with(name, 'rg-Ignite')].{name:name, location:location}" -o json 2>/dev/null || echo "[]")
IGNITE_RG_COUNT=$(echo "$IGNITE_RGS" | jq length)

DEFAULT_RG=""
DEFAULT_LOCATION=""

if [ "$IGNITE_RG_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No resource groups found with 'rg-Ignite' prefix${NC}"
    echo -e "${CYAN}Available resource groups:${NC}"
    az group list --query "[].{name:name, location:location}" -o table
    echo ""
elif [ "$IGNITE_RG_COUNT" -eq 1 ]; then
    DEFAULT_RG=$(echo "$IGNITE_RGS" | jq -r '.[0].name')
    DEFAULT_LOCATION=$(echo "$IGNITE_RGS" | jq -r '.[0].location')
    echo -e "${GREEN}✓ Found 1 resource group with 'rg-Ignite' prefix:${NC}"
    echo -e "  ${BOLD}→ $DEFAULT_RG${NC} (${DEFAULT_LOCATION})\n"
else
    echo -e "${GREEN}✓ Found $IGNITE_RG_COUNT resource groups with 'rg-Ignite' prefix:${NC}"
    echo "$IGNITE_RGS" | jq -r '.[] | "  • \(.name) (\(.location))"'
    echo ""
    DEFAULT_RG=$(echo "$IGNITE_RGS" | jq -r '.[0].name')
    DEFAULT_LOCATION=$(echo "$IGNITE_RGS" | jq -r '.[0].location')
    echo -e "${CYAN}Default selection:${NC} ${BOLD}$DEFAULT_RG${NC}\n"
fi

# Prompt user for resource group (with default)
echo -e "${CYAN}${BOLD}Enter resource group name${NC}"
if [ -n "$DEFAULT_RG" ]; then
    echo -e "${CYAN}(Press Enter to use: ${BOLD}$DEFAULT_RG${NC}${CYAN})${NC}"
fi
echo -n "> "
read -r USER_INPUT_RG

if [ -z "$USER_INPUT_RG" ] && [ -n "$DEFAULT_RG" ]; then
    AZURE_RESOURCE_GROUP="$DEFAULT_RG"
    AZURE_LOCATION="$DEFAULT_LOCATION"
    echo -e "${GREEN}Using default: $AZURE_RESOURCE_GROUP${NC}\n"
elif [ -n "$USER_INPUT_RG" ]; then
    AZURE_RESOURCE_GROUP="$USER_INPUT_RG"
    # Get location for the specified resource group
    RG_INFO=$(az group show --name "$AZURE_RESOURCE_GROUP" --query "{name:name, location:location}" -o json 2>/dev/null || echo "{}")
    if [ "$(echo "$RG_INFO" | jq -r '.name')" == "null" ]; then
        echo -e "${RED}✗ Resource group '$AZURE_RESOURCE_GROUP' not found${NC}"
        exit 1
    fi
    AZURE_LOCATION=$(echo "$RG_INFO" | jq -r '.location')
    echo -e "${GREEN}Using: $AZURE_RESOURCE_GROUP ($AZURE_LOCATION)${NC}\n"
else
    echo -e "${RED}✗ No resource group specified${NC}"
    exit 1
fi

# ============================================================================
# Step 4: List all resources for verification
# ============================================================================
echo -e "${YELLOW}Step 4: Discovering resources in $AZURE_RESOURCE_GROUP...${NC}"

ALL_RESOURCES=$(az resource list --resource-group "$AZURE_RESOURCE_GROUP" --query "[].{name:name, type:type}" -o json 2>/dev/null || echo "[]")
RESOURCE_COUNT=$(echo "$ALL_RESOURCES" | jq length)

if [ "$RESOURCE_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ No resources found in resource group '$AZURE_RESOURCE_GROUP'${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found $RESOURCE_COUNT resources${NC}"
echo -e "${CYAN}Resource types:${NC}"
echo "$ALL_RESOURCES" | jq -r '[.[] | .type] | unique | .[]' | sort | sed 's/^/  • /'
echo ""

# ============================================================================
# Step 5: Discover Azure OpenAI resources
# ============================================================================
echo -e "${YELLOW}Step 5: Discovering Azure OpenAI resources...${NC}"

AOAI_RESOURCES=$(az resource list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --resource-type "Microsoft.CognitiveServices/accounts" \
    --query "[?kind=='OpenAI' || kind=='AIServices'].{name:name, id:id, kind:kind}" \
    -o json 2>/dev/null || echo "[]")

AOAI_COUNT=$(echo "$AOAI_RESOURCES" | jq length 2>/dev/null || echo "0")

if [ "$AOAI_COUNT" -gt 0 ]; then
    AOAI_NAME=$(echo "$AOAI_RESOURCES" | jq -r '.[0].name')
    AOAI_KIND=$(echo "$AOAI_RESOURCES" | jq -r '.[0].kind')
    
    # Construct the OpenAI endpoint using the OpenAI format
    # The OpenAI format is: https://{resource-name}.openai.azure.com/
    AZURE_OPENAI_ENDPOINT="https://${AOAI_NAME}.openai.azure.com/"
    
    # Get API key
    # AZURE_OPENAI_API_KEY=$(az cognitiveservices account keys list \
    #     --name "$AOAI_NAME" \
    #     --resource-group "$AZURE_RESOURCE_GROUP" \
    #     --query "key1" \
    #     -o tsv 2>/dev/null || echo "")

    echo -e "${GREEN}✓ Found Azure OpenAI: $AOAI_NAME${NC}"
    echo -e "  ${BOLD}Kind:${NC} $AOAI_KIND"
    echo -e "  ${BOLD}Endpoint:${NC} $AZURE_OPENAI_ENDPOINT"
    
    # if [ -n "$AZURE_OPENAI_API_KEY" ]; then
    #     echo -e "  ${BOLD}API Key:${NC} ${AZURE_OPENAI_API_KEY:0:8}***"
    # fi
    
    # Get deployments
    echo -e "  ${CYAN}Discovering model deployments...${NC}"
    DEPLOYMENTS=$(az cognitiveservices account deployment list \
        --name "$AOAI_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "[].{name:name, model:properties.model.name, version:properties.model.version, capacity:sku.capacity}" \
        -o json 2>/dev/null || echo "[]")
    
    DEPLOYMENT_COUNT=$(echo "$DEPLOYMENTS" | jq length)
    echo -e "  ${BOLD}Deployments:${NC} $DEPLOYMENT_COUNT found"
    
    if [ "$DEPLOYMENT_COUNT" -gt 0 ]; then
        echo "$DEPLOYMENTS" | jq -r '.[] | "    - \(.name) (\(.model) v\(.version))"'
    fi
    
    # Identify agent deployment (GPT-4)
    AZURE_AI_AGENT_DEPLOYMENT_NAME=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("gpt-4"; "i"))] | .[0].name // ""')
    AZURE_AI_AGENT_MODEL_NAME=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("gpt-4"; "i"))] | .[0].model // "gpt-4"')
    AZURE_AI_AGENT_MODEL_VERSION=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("gpt-4"; "i"))] | .[0].version // "2024-05-13"')
    AZURE_AI_AGENT_DEPLOYMENT_CAPACITY=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("gpt-4"; "i"))] | .[0].capacity // "10"')
    
    # Identify embedding deployment
    AZURE_AI_EMBED_DEPLOYMENT_NAME=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("embedding|embed"; "i"))] | .[0].name // ""')
    AZURE_AI_EMBED_MODEL_NAME=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("embedding|embed"; "i"))] | .[0].model // "text-embedding-3-large"')
    AZURE_AI_EMBED_MODEL_VERSION=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("embedding|embed"; "i"))] | .[0].version // "2"')
    AZURE_AI_EMBED_DEPLOYMENT_CAPACITY=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("embedding|embed"; "i"))] | .[0].capacity // "10"')
    
    if [ -n "$AZURE_AI_AGENT_DEPLOYMENT_NAME" ]; then
        echo -e "  ${BOLD}Agent Model:${NC} $AZURE_AI_AGENT_DEPLOYMENT_NAME ($AZURE_AI_AGENT_MODEL_NAME)"
    fi
    
    if [ -n "$AZURE_AI_EMBED_DEPLOYMENT_NAME" ]; then
        echo -e "  ${BOLD}Embedding Model:${NC} $AZURE_AI_EMBED_DEPLOYMENT_NAME ($AZURE_AI_EMBED_MODEL_NAME)"
    fi
else
    echo -e "${YELLOW}⚠ No Azure OpenAI resources found${NC}"
    AOAI_NAME=""
    AZURE_OPENAI_ENDPOINT=""
    #AZURE_OPENAI_API_KEY=""
    AZURE_AI_AGENT_DEPLOYMENT_NAME="gpt-4"
    AZURE_AI_AGENT_MODEL_NAME="gpt-4"
    AZURE_AI_AGENT_MODEL_VERSION="2024-05-13"
    AZURE_AI_AGENT_DEPLOYMENT_CAPACITY="10"
    AZURE_AI_EMBED_DEPLOYMENT_NAME="text-embedding-3-large"
    AZURE_AI_EMBED_MODEL_NAME="text-embedding-3-large"
    AZURE_AI_EMBED_MODEL_VERSION="2"
    AZURE_AI_EMBED_DEPLOYMENT_CAPACITY="10"
fi
echo ""

# ============================================================================
# Step 6: Discover Azure AI Search resources
# ============================================================================
echo -e "${YELLOW}Step 6: Discovering Azure AI Search resources...${NC}"

SEARCH_SERVICES=$(az search service list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "[].{name:name}" \
    -o json 2>/dev/null || echo "[]")

SEARCH_COUNT=$(echo "$SEARCH_SERVICES" | jq length)

if [ "$SEARCH_COUNT" -gt 0 ]; then
    SEARCH_NAME=$(echo "$SEARCH_SERVICES" | jq -r '.[0].name')
    AZURE_AI_SEARCH_ENDPOINT="https://${SEARCH_NAME}.search.windows.net"
    
    echo -e "${GREEN}✓ Found Azure AI Search: $SEARCH_NAME${NC}"
    echo -e "  ${BOLD}Endpoint:${NC} $AZURE_AI_SEARCH_ENDPOINT"
    
    # Get API key
    AZURE_SEARCH_API_KEY=$(az search admin-key show \
        --service-name "$SEARCH_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "primaryKey" \
        -o tsv 2>/dev/null || echo "")
    
    if [ -n "$AZURE_SEARCH_API_KEY" ]; then
        echo -e "  ${BOLD}API Key:${NC} ${AZURE_SEARCH_API_KEY:0:8}***"
    fi
    
    # Try to get indexes
    INDEXES=$(az search index list \
        --service-name "$SEARCH_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "[].name" \
        -o tsv 2>/dev/null || echo "")
    
    if [ -n "$INDEXES" ]; then
        INDEX_COUNT=$(echo "$INDEXES" | wc -l)
        AZURE_AI_SEARCH_INDEX_NAME=$(echo "$INDEXES" | head -n 1)
        echo -e "  ${BOLD}Indexes:${NC} $INDEX_COUNT found"
        echo "$INDEXES" | sed 's/^/    - /'
        echo -e "  ${BOLD}Using:${NC} $AZURE_AI_SEARCH_INDEX_NAME"
    else
        AZURE_AI_SEARCH_INDEX_NAME="zava-products"
        echo -e "  ${YELLOW}No indexes found, using default: $AZURE_AI_SEARCH_INDEX_NAME${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No Azure AI Search resources found${NC}"
    SEARCH_NAME=""
    AZURE_AI_SEARCH_ENDPOINT=""
    AZURE_SEARCH_API_KEY=""
    AZURE_AI_SEARCH_INDEX_NAME="zava-products"
fi
echo ""

# ============================================================================
# Step 7: Discover AI Foundry Project (child of AI Service)
# ============================================================================
echo -e "${YELLOW}Step 7: Discovering AI Foundry Project...${NC}"

if [ -z "$AOAI_NAME" ]; then
    echo -e "${YELLOW}⚠ No AI Service found - skipping project search${NC}"
    AZURE_AI_PROJECT_NAME=""
    AZURE_EXISTING_AIPROJECT_RESOURCE_ID=""
    AZURE_EXISTING_AIPROJECT_ENDPOINT=""
else
    echo -e "${CYAN}Searching for AI Projects under AI Service: $AOAI_NAME${NC}"
    
    # List AI projects as child resources of the AI Service
    AI_PROJECTS_RAW=$(az resource list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --resource-type "Microsoft.CognitiveServices/accounts/projects" \
        --query "[].name" \
        -o tsv 2>/dev/null || echo "")
    
    # Filter projects that belong to the selected AI Service
    AI_PROJECTS=()
    while IFS= read -r project; do
        if [[ "$project" == "$AOAI_NAME/"* ]]; then
            # Extract project name after the /
            project_name="${project#*/}"
            AI_PROJECTS+=("$project_name")
        fi
    done <<< "$AI_PROJECTS_RAW"
    
    AI_PROJECT_COUNT=${#AI_PROJECTS[@]}
    
    if [ "$AI_PROJECT_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}⚠ No AI Foundry Projects found under $AOAI_NAME${NC}"
        AZURE_AI_PROJECT_NAME=""
        AZURE_EXISTING_AIPROJECT_RESOURCE_ID=""
        AZURE_EXISTING_AIPROJECT_ENDPOINT=""
    elif [ "$AI_PROJECT_COUNT" -eq 1 ]; then
        AZURE_AI_PROJECT_NAME="${AI_PROJECTS[0]}"
        
        # Get project resource ID by listing all resources and filtering
        AZURE_EXISTING_AIPROJECT_RESOURCE_ID=$(az resource list \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --resource-type "Microsoft.CognitiveServices/accounts/projects" \
            --query "[?name=='$AOAI_NAME/$AZURE_AI_PROJECT_NAME'].id | [0]" \
            -o tsv 2>/dev/null || echo "")
        
        # Get project details for endpoint if we have the resource ID
        if [ -n "$AZURE_EXISTING_AIPROJECT_RESOURCE_ID" ]; then
            PROJECT_DATA=$(az resource show \
                --ids "$AZURE_EXISTING_AIPROJECT_RESOURCE_ID" \
                --query "{endpoint:properties.endpoints.\"AI Foundry API\"}" \
                -o json 2>/dev/null || echo "{}")
            
            AZURE_EXISTING_AIPROJECT_ENDPOINT=$(echo "$PROJECT_DATA" | jq -r '.endpoint // ""')
        else
            AZURE_EXISTING_AIPROJECT_ENDPOINT=""
        fi
        
        # Construct endpoint if not found
        if [ -z "$AZURE_EXISTING_AIPROJECT_ENDPOINT" ] || [ "$AZURE_EXISTING_AIPROJECT_ENDPOINT" = "null" ]; then
            AZURE_EXISTING_AIPROJECT_ENDPOINT="https://$AOAI_NAME.services.ai.azure.com/api/projects/$AZURE_AI_PROJECT_NAME"
        fi
        
        echo -e "${GREEN}✓ Found AI Foundry Project: $AZURE_AI_PROJECT_NAME${NC}"
        echo -e "  ${BOLD}Full Name:${NC} $AOAI_NAME/$AZURE_AI_PROJECT_NAME"
        echo -e "  ${BOLD}Resource ID:${NC} $AZURE_EXISTING_AIPROJECT_RESOURCE_ID"
        echo -e "  ${BOLD}Endpoint:${NC} $AZURE_EXISTING_AIPROJECT_ENDPOINT"
    else
        echo -e "${GREEN}✓ Found $AI_PROJECT_COUNT AI Foundry Projects:${NC}"
        for proj in "${AI_PROJECTS[@]}"; do
            echo -e "    - $proj"
        done
        
        # Use the first project
        AZURE_AI_PROJECT_NAME="${AI_PROJECTS[0]}"
        
        # Get project resource ID by listing all resources and filtering
        AZURE_EXISTING_AIPROJECT_RESOURCE_ID=$(az resource list \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --resource-type "Microsoft.CognitiveServices/accounts/projects" \
            --query "[?name=='$AOAI_NAME/$AZURE_AI_PROJECT_NAME'].id | [0]" \
            -o tsv 2>/dev/null || echo "")
        
        # Get project details for endpoint if we have the resource ID
        if [ -n "$AZURE_EXISTING_AIPROJECT_RESOURCE_ID" ]; then
            PROJECT_DATA=$(az resource show \
                --ids "$AZURE_EXISTING_AIPROJECT_RESOURCE_ID" \
                --query "{endpoint:properties.endpoints.\"AI Foundry API\"}" \
                -o json 2>/dev/null || echo "{}")
            
            AZURE_EXISTING_AIPROJECT_ENDPOINT=$(echo "$PROJECT_DATA" | jq -r '.endpoint // ""')
        else
            AZURE_EXISTING_AIPROJECT_ENDPOINT=""
        fi
        
        # Construct endpoint if not found
        if [ -z "$AZURE_EXISTING_AIPROJECT_ENDPOINT" ] || [ "$AZURE_EXISTING_AIPROJECT_ENDPOINT" = "null" ]; then
            AZURE_EXISTING_AIPROJECT_ENDPOINT="https://$AOAI_NAME.services.ai.azure.com/api/projects/$AZURE_AI_PROJECT_NAME"
        fi
        
        echo -e "${CYAN}Using first project:${NC} ${BOLD}$AZURE_AI_PROJECT_NAME${NC}"
        echo -e "  ${BOLD}Full Name:${NC} $AOAI_NAME/$AZURE_AI_PROJECT_NAME"
        echo -e "  ${BOLD}Resource ID:${NC} $AZURE_EXISTING_AIPROJECT_RESOURCE_ID"
        echo -e "  ${BOLD}Endpoint:${NC} $AZURE_EXISTING_AIPROJECT_ENDPOINT"
    fi
fi
echo ""

# ============================================================================
# Step 8: Configure Agent Name
# ============================================================================
echo -e "${YELLOW}Step 8: Configuring Agent Name...${NC}"

DEFAULT_AGENT_NAME="agent-template-assistant"

echo -e "${CYAN}${BOLD}Enter agent name${NC}"
echo -e "${CYAN}(Press Enter to use default: ${BOLD}$DEFAULT_AGENT_NAME${NC}${CYAN})${NC}"
echo -n "> "
read -r USER_INPUT_AGENT

if [ -z "$USER_INPUT_AGENT" ]; then
    AZURE_AI_AGENT_NAME="$DEFAULT_AGENT_NAME"
    echo -e "${GREEN}Using default: $AZURE_AI_AGENT_NAME${NC}"
else
    AZURE_AI_AGENT_NAME="$USER_INPUT_AGENT"
    echo -e "${GREEN}Using: $AZURE_AI_AGENT_NAME${NC}"
fi
echo ""

# ============================================================================
# Step 9: Discover Application Insights
# ============================================================================
echo -e "${YELLOW}Step 9: Discovering Application Insights...${NC}"

APPINSIGHTS_RESOURCES=$(az resource list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --resource-type "Microsoft.Insights/components" \
    --query "[].name" \
    -o tsv 2>/dev/null || echo "")

if [ -n "$APPINSIGHTS_RESOURCES" ]; then
    APPINSIGHTS_NAME=$(echo "$APPINSIGHTS_RESOURCES" | head -n 1)
    
    APPINSIGHTS_DATA=$(az resource show \
        --ids "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Insights/components/$APPINSIGHTS_NAME" \
        --query "{connectionString: properties.ConnectionString, instrumentationKey: properties.InstrumentationKey}" \
        -o json 2>/dev/null || echo "{}")
    
    APPINSIGHTS_CONNECTION_STRING=$(echo "$APPINSIGHTS_DATA" | jq -r '.connectionString // ""')
    APPINSIGHTS_INSTRUMENTATION_KEY=$(echo "$APPINSIGHTS_DATA" | jq -r '.instrumentationKey // ""')
    
    echo -e "${GREEN}✓ Found Application Insights: $APPINSIGHTS_NAME${NC}"
    
    if [ -n "$APPINSIGHTS_CONNECTION_STRING" ]; then
        echo -e "  ${BOLD}Connection String:${NC} ${APPINSIGHTS_CONNECTION_STRING:0:50}..."
    fi
else
    echo -e "${YELLOW}⚠ No Application Insights found${NC}"
    APPINSIGHTS_NAME=""
    APPINSIGHTS_CONNECTION_STRING=""
    APPINSIGHTS_INSTRUMENTATION_KEY=""
fi
echo ""

# ============================================================================
# Step 10: Discover Container Registry and Container Apps
# ============================================================================
echo -e "${YELLOW}Step 10: Discovering Container resources...${NC}"

# Container Registry
ACR_RESOURCES=$(az acr list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "[].{name:name, loginServer:loginServer}" \
    -o json 2>/dev/null || echo "[]")

ACR_COUNT=$(echo "$ACR_RESOURCES" | jq length)

if [ "$ACR_COUNT" -gt 0 ]; then
    ACR_NAME=$(echo "$ACR_RESOURCES" | jq -r '.[0].name')
    AZURE_CONTAINER_REGISTRY_ENDPOINT=$(echo "$ACR_RESOURCES" | jq -r '.[0].loginServer')
    echo -e "${GREEN}✓ Found Container Registry: $ACR_NAME${NC}"
    echo -e "  ${BOLD}Endpoint:${NC} $AZURE_CONTAINER_REGISTRY_ENDPOINT"
else
    echo -e "${YELLOW}⚠ No Container Registry found${NC}"
    ACR_NAME=""
    AZURE_CONTAINER_REGISTRY_ENDPOINT=""
fi

# Container Apps Environment
CONTAINERAPP_ENV=$(az containerapp env list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "[].name" \
    -o tsv 2>/dev/null || echo "")

if [ -n "$CONTAINERAPP_ENV" ]; then
    AZURE_CONTAINER_ENVIRONMENT_NAME=$(echo "$CONTAINERAPP_ENV" | head -n 1)
    echo -e "${GREEN}✓ Found Container Apps Environment: $AZURE_CONTAINER_ENVIRONMENT_NAME${NC}"
    
    # Find container apps in the environment
    CONTAINER_APPS=$(az containerapp list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "[].{name:name, fqdn:properties.configuration.ingress.fqdn}" \
        -o json 2>/dev/null || echo "[]")
    
    APP_COUNT=$(echo "$CONTAINER_APPS" | jq length)
    
    if [ "$APP_COUNT" -gt 0 ]; then
        SERVICE_API_NAME=$(echo "$CONTAINER_APPS" | jq -r '.[0].name')
        SERVICE_API_FQDN=$(echo "$CONTAINER_APPS" | jq -r '.[0].fqdn // ""')
        
        if [ -n "$SERVICE_API_FQDN" ]; then
            SERVICE_API_URI="https://$SERVICE_API_FQDN"
            echo -e "  ${BOLD}Service API:${NC} $SERVICE_API_NAME"
            echo -e "  ${BOLD}Service URI:${NC} $SERVICE_API_URI"
        else
            SERVICE_API_URI=""
        fi
        
        # Get service principal ID (managed identity)
        # Try system-assigned identity first
        SERVICE_API_IDENTITY_PRINCIPAL_ID=$(az containerapp show \
            --name "$SERVICE_API_NAME" \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --query "identity.principalId" \
            -o tsv 2>/dev/null || echo "")
        
        # If no system-assigned identity, try user-assigned identities
        if [ -z "$SERVICE_API_IDENTITY_PRINCIPAL_ID" ] || [ "$SERVICE_API_IDENTITY_PRINCIPAL_ID" = "null" ]; then
            SERVICE_API_IDENTITY_PRINCIPAL_ID=$(az containerapp show \
                --name "$SERVICE_API_NAME" \
                --resource-group "$AZURE_RESOURCE_GROUP" \
                --query "identity.userAssignedIdentities.*.principalId | [0]" \
                -o tsv 2>/dev/null || echo "")
        fi
        
        if [ -n "$SERVICE_API_IDENTITY_PRINCIPAL_ID" ] && [ "$SERVICE_API_IDENTITY_PRINCIPAL_ID" != "null" ]; then
            echo -e "  ${BOLD}Identity Principal ID:${NC} $SERVICE_API_IDENTITY_PRINCIPAL_ID"
        else
            echo -e "  ${YELLOW}⚠ No managed identity found on Container App${NC}"
            SERVICE_API_IDENTITY_PRINCIPAL_ID=""
        fi
    else
        SERVICE_API_NAME=""
        SERVICE_API_URI=""
        SERVICE_API_IDENTITY_PRINCIPAL_ID=""
    fi
else
    echo -e "${YELLOW}⚠ No Container Apps Environment found${NC}"
    AZURE_CONTAINER_ENVIRONMENT_NAME=""
    SERVICE_API_NAME=""
    SERVICE_API_URI=""
    SERVICE_API_IDENTITY_PRINCIPAL_ID=""
fi
echo ""

# ============================================================================
# Step 11: Generate the .env file
# ============================================================================
echo -e "${YELLOW}Step 11: Generating .env file...${NC}"

# Backup existing .env if it exists
if [ -f "$ENV_FILE" ]; then
    BACKUP_FILE="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ENV_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Backed up existing .env to: ${BACKUP_FILE##*/}${NC}"
fi

# Set default values for variables not discovered
AZURE_ENV_NAME="${AZURE_ENV_NAME:-${AZURE_RESOURCE_GROUP#rg-}}"
AZURE_OPENAI_API_VERSION="2025-02-01-preview"
# AZURE_AI_AGENT_NAME is set in Step 8 (user prompt)
AZURE_AI_EMBED_DEPLOYMENT_SKU="${AZURE_AI_EMBED_DEPLOYMENT_SKU:-Standard}"
AZURE_AI_EMBED_DIMENSIONS="${AZURE_AI_EMBED_DIMENSIONS:-3072}"
AZURE_AI_EMBED_MODEL_FORMAT="${AZURE_AI_EMBED_MODEL_FORMAT:-float}"
SERVICE_API_ENDPOINTS="${SERVICE_API_ENDPOINTS:-[]}"
SERVICE_API_AND_FRONTEND_IMAGE_NAME="${SERVICE_API_AND_FRONTEND_IMAGE_NAME:-contoso-outdoor-app}"
USE_APPLICATION_INSIGHTS="${USE_APPLICATION_INSIGHTS:-true}"
ENABLE_AZURE_MONITOR_TRACING="${ENABLE_AZURE_MONITOR_TRACING:-true}"
AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED="${AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED:-true}"

# Generate .env file
cat > "$ENV_FILE" << EOF
# ============================================================================
# Azure Environment Variables
# Auto-generated by scripts/1-get-env-selfguided.sh on $(date)
# Resource Group: $AZURE_RESOURCE_GROUP
# ============================================================================

# .... Azure Environment Variables
AZURE_ENV_NAME="$AZURE_ENV_NAME"
AZURE_LOCATION="$AZURE_LOCATION"
AZURE_RESOURCE_GROUP="$AZURE_RESOURCE_GROUP"
AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
AZURE_TENANT_ID="$AZURE_TENANT_ID"

# .... Azure AI Foundry (OpenAI endpoint and credentials)
#AZURE_OPENAI_API_KEY="$AZURE_OPENAI_API_KEY"
AZURE_OPENAI_ENDPOINT="$AZURE_OPENAI_ENDPOINT"
AZURE_OPENAI_API_VERSION="$AZURE_OPENAI_API_VERSION"
AZURE_OPENAI_DEPLOYMENT="$AZURE_AI_AGENT_DEPLOYMENT_NAME"

# .... Azure AI Foundry Resources (AI Service and Project)
AZURE_AI_FOUNDRY_NAME="$AOAI_NAME"
AZURE_AI_PROJECT_NAME="$AZURE_AI_PROJECT_NAME"
AZURE_EXISTING_AIPROJECT_ENDPOINT="$AZURE_EXISTING_AIPROJECT_ENDPOINT"
AZURE_EXISTING_AIPROJECT_RESOURCE_ID="$AZURE_EXISTING_AIPROJECT_RESOURCE_ID"

# .... Azure AI Search (Required for add-product-index script)
AZURE_SEARCH_ENDPOINT="$AZURE_AI_SEARCH_ENDPOINT"
AZURE_AISEARCH_ENDPOINT="$AZURE_AI_SEARCH_ENDPOINT"
AZURE_AI_SEARCH_ENDPOINT="$AZURE_AI_SEARCH_ENDPOINT"
AZURE_SEARCH_API_KEY="$AZURE_SEARCH_API_KEY"
AZURE_SEARCH_INDEX_NAME="$AZURE_AI_SEARCH_INDEX_NAME"
AZURE_AISEARCH_INDEX="$AZURE_AI_SEARCH_INDEX_NAME"
AZURE_AI_SEARCH_INDEX_NAME="$AZURE_AI_SEARCH_INDEX_NAME"

# .... Agent Configuration
AZURE_AI_AGENT_DEPLOYMENT_NAME="$AZURE_AI_AGENT_DEPLOYMENT_NAME"
AZURE_AI_AGENT_MODEL_NAME="$AZURE_AI_AGENT_MODEL_NAME"
AZURE_AI_AGENT_MODEL_VERSION="$AZURE_AI_AGENT_MODEL_VERSION"
AZURE_AI_AGENT_DEPLOYMENT_CAPACITY=$AZURE_AI_AGENT_DEPLOYMENT_CAPACITY
AZURE_AI_AGENT_NAME="$AZURE_AI_AGENT_NAME"

# .... Embedding Model Configuration
AZURE_AI_EMBED_DEPLOYMENT_NAME="$AZURE_AI_EMBED_DEPLOYMENT_NAME"
AZURE_AI_EMBED_MODEL_NAME="$AZURE_AI_EMBED_MODEL_NAME"
AZURE_AI_EMBED_MODEL_VERSION=$AZURE_AI_EMBED_MODEL_VERSION
AZURE_AI_EMBED_DEPLOYMENT_CAPACITY=$AZURE_AI_EMBED_DEPLOYMENT_CAPACITY
AZURE_AI_EMBED_DEPLOYMENT_SKU="$AZURE_AI_EMBED_DEPLOYMENT_SKU"
AZURE_AI_EMBED_DIMENSIONS=$AZURE_AI_EMBED_DIMENSIONS
AZURE_AI_EMBED_MODEL_FORMAT="$AZURE_AI_EMBED_MODEL_FORMAT"

# .... Container Apps & Registry
AZURE_CONTAINER_ENVIRONMENT_NAME="$AZURE_CONTAINER_ENVIRONMENT_NAME"
AZURE_CONTAINER_REGISTRY_ENDPOINT="$AZURE_CONTAINER_REGISTRY_ENDPOINT"
SERVICE_API_NAME="$SERVICE_API_NAME"
SERVICE_API_URI="$SERVICE_API_URI"
SERVICE_API_ENDPOINTS='$SERVICE_API_ENDPOINTS'
SERVICE_API_IDENTITY_PRINCIPAL_ID="$SERVICE_API_IDENTITY_PRINCIPAL_ID"
SERVICE_API_AND_FRONTEND_IMAGE_NAME="$SERVICE_API_AND_FRONTEND_IMAGE_NAME"

# .... Monitoring & Tracing
USE_APPLICATION_INSIGHTS="$USE_APPLICATION_INSIGHTS"
ENABLE_AZURE_MONITOR_TRACING="$ENABLE_AZURE_MONITOR_TRACING"
AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED="$AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED"
APPLICATIONINSIGHTS_CONNECTION_STRING="$APPINSIGHTS_CONNECTION_STRING"
APPLICATIONINSIGHTS_INSTRUMENTATION_KEY="$APPINSIGHTS_INSTRUMENTATION_KEY"

# .... Tracing Lab (additional variables for tracing exercises)
API_HOST="$SERVICE_API_URI"
APPLICATION_INSIGHTS_CONNECTION_STRING="$APPINSIGHTS_CONNECTION_STRING"
AZURE_OPENAI_VERSION="$AZURE_OPENAI_API_VERSION"
AZURE_OPENAI_CHAT_DEPLOYMENT="$AZURE_AI_AGENT_DEPLOYMENT_NAME"
EOF

echo -e "${GREEN}✓ Generated .env file at: $ENV_FILE${NC}\n"

# ============================================================================
# Step 12: Summary
# ============================================================================
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}✅ Environment Setup Complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}${BOLD}Summary of discovered resources:${NC}\n"

echo -e "${BOLD}Core Resources:${NC}"
echo -e "  • Resource Group: ${GREEN}$AZURE_RESOURCE_GROUP${NC}"
echo -e "  • Location: ${GREEN}$AZURE_LOCATION${NC}"
echo -e "  • Total Resources: ${GREEN}$RESOURCE_COUNT${NC}\n"

if [ -n "$AOAI_NAME" ]; then
    echo -e "${BOLD}Azure OpenAI:${NC}"
    echo -e "  • Service: ${GREEN}$AOAI_NAME${NC}"
    echo -e "  • Agent Model: ${GREEN}${AZURE_AI_AGENT_DEPLOYMENT_NAME:-Not found}${NC}"
    echo -e "  • Embedding Model: ${GREEN}${AZURE_AI_EMBED_DEPLOYMENT_NAME:-Not found}${NC}\n"
else
    echo -e "${BOLD}Azure OpenAI:${NC} ${YELLOW}Not found${NC}\n"
fi

if [ -n "$SEARCH_NAME" ]; then
    echo -e "${BOLD}Azure AI Search:${NC}"
    echo -e "  • Service: ${GREEN}$SEARCH_NAME${NC}"
    echo -e "  • Index: ${GREEN}$AZURE_AI_SEARCH_INDEX_NAME${NC}\n"
else
    echo -e "${BOLD}Azure AI Search:${NC} ${YELLOW}Not found${NC}\n"
fi

if [ -n "$AZURE_AI_PROJECT_NAME" ]; then
    echo -e "${BOLD}AI Foundry Project:${NC} ${GREEN}$AZURE_AI_PROJECT_NAME${NC}\n"
else
    echo -e "${BOLD}AI Foundry Project:${NC} ${YELLOW}Not found${NC}\n"
fi

echo -e "${BOLD}Agent Configuration:${NC}"
echo -e "  • Agent Name: ${GREEN}$AZURE_AI_AGENT_NAME${NC}\n"

if [ -n "$APPINSIGHTS_NAME" ]; then
    echo -e "${BOLD}Application Insights:${NC} ${GREEN}$APPINSIGHTS_NAME${NC}\n"
else
    echo -e "${BOLD}Application Insights:${NC} ${YELLOW}Not found${NC}\n"
fi

if [ -n "$ACR_NAME" ]; then
    echo -e "${BOLD}Container Registry:${NC} ${GREEN}$ACR_NAME${NC}\n"
else
    echo -e "${BOLD}Container Registry:${NC} ${YELLOW}Not found${NC}\n"
fi

echo -e "${CYAN}${BOLD}Next Steps:${NC}"
echo -e "  1. Review the generated ${BOLD}.env${NC} file"
echo -e "  2. Source the environment: ${BLUE}source .env${NC}"
echo -e "  3. Start working with your Azure resources!\n"

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
