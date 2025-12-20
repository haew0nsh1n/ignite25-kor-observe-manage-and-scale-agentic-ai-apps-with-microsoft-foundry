#!/bin/bash

# ---------------------------------------------------------------------------------------------------------------------------------
# Add Model Choices Script - Adds additional AI model deployments to existing infrastructure
# - Reads available models from customization/add-models.json
# - Allows user to select which models to deploy
# - Updates infrastructure with selected models
# - Uses .env file instead of azd environment
#
# Prerequisites:
# - .env file must exist in the repository root
# - Azure infrastructure must be deployed
# - Azure CLI must be authenticated
# ---------------------------------------------------------------------------------------------------------------------------------

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MODELS_CONFIG="$SCRIPT_DIR/customization/add-models.json"

# Find the repository root
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ "$REPO_ROOT" != "" ]; do
    if [ -d "$REPO_ROOT/.git" ]; then
        break
    fi
    REPO_ROOT=$(dirname "$REPO_ROOT")
done

# If .git not found, just go up one level from scripts directory
if [ "$REPO_ROOT" == "/" ] || [ "$REPO_ROOT" == "" ]; then
    REPO_ROOT=$(dirname "$SCRIPT_DIR")
fi

ENV_FILE="$REPO_ROOT/.env"

#==============================================================================
# Helper Functions
#==============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        log_error ".env file not found at: $ENV_FILE"
        log_error "Please run one of the setup scripts first to create the .env file:"
        log_error "  - 1-get-env-selfguided.sh"
        log_error "  - 7-get-env-skillable.sh"
        exit 1
    fi
    
    log_info "Loading environment from: $ENV_FILE"
    source "$ENV_FILE"
    
    # Check if Azure CLI is authenticated
    if ! az account show &> /dev/null; then
        log_error "You are not logged into Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check required environment variables
    if [ -z "$AZURE_RESOURCE_GROUP" ]; then
        log_error "AZURE_RESOURCE_GROUP is not set in .env file"
        exit 1
    fi
    
    if [ -z "$AZURE_AI_FOUNDRY_NAME" ]; then
        log_error "AZURE_AI_FOUNDRY_NAME is not set in .env file"
        log_error "This should be the name of your Azure AI Services (Cognitive Services) account"
        exit 1
    fi
    
    # Check if models config file exists
    if [ ! -f "$MODELS_CONFIG" ]; then
        log_error "Models configuration file not found at: $MODELS_CONFIG"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Please install jq."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
    log_info "Resource Group: $AZURE_RESOURCE_GROUP"
}

get_ai_account_name() {
    # Use the AI Foundry name directly - it's the Cognitive Services account name
    AI_ACCOUNT_NAME="$AZURE_AI_FOUNDRY_NAME"
    
    if [ -z "$AI_ACCOUNT_NAME" ]; then
        log_error "Could not get AI account name from AZURE_AI_FOUNDRY_NAME"
        exit 1
    fi
    
    log_info "AI Account: $AI_ACCOUNT_NAME"
}

get_current_deployments() {
    log_info "Retrieving current model deployments..."
    
    CURRENT_DEPLOYMENTS=()
    
    # Add base agent deployment if set
    [ -n "$AZURE_AI_AGENT_DEPLOYMENT_NAME" ] && CURRENT_DEPLOYMENTS+=("$AZURE_AI_AGENT_DEPLOYMENT_NAME")
    
    # Add base embedding deployment if set
    [ -n "$AZURE_AI_EMBED_DEPLOYMENT_NAME" ] && CURRENT_DEPLOYMENTS+=("$AZURE_AI_EMBED_DEPLOYMENT_NAME")
    
    # Check for additional models from environment variable
    if [ -n "$ADDITIONAL_MODEL_DEPLOYMENTS" ] && [ "$ADDITIONAL_MODEL_DEPLOYMENTS" != "[]" ]; then
        # Validate it's valid JSON
        if echo "$ADDITIONAL_MODEL_DEPLOYMENTS" | jq empty 2>/dev/null; then
            local additional_count=$(echo "$ADDITIONAL_MODEL_DEPLOYMENTS" | jq '. | length' 2>/dev/null || echo "0")
            for ((i=0; i<$additional_count; i++)); do
                local dep_name=$(echo "$ADDITIONAL_MODEL_DEPLOYMENTS" | jq -r ".[$i].name" 2>/dev/null || echo "")
                [ -n "$dep_name" ] && CURRENT_DEPLOYMENTS+=("$dep_name")
            done
        fi
    fi
    
    log_success "Retrieved ${#CURRENT_DEPLOYMENTS[@]} existing deployments"
}

display_deployed_models() {
    if [ ${#CURRENT_DEPLOYMENTS[@]} -eq 0 ]; then
        return
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Currently Deployed Models${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    for deployment in "${CURRENT_DEPLOYMENTS[@]}"; do
        # Only display if deployment name is not empty
        if [ -n "$deployment" ] && [ "$deployment" != "null" ]; then
            echo -e "${GREEN}✓ $deployment${NC}"
        fi
    done
    
    echo ""
}

display_available_models() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Available Models to Deploy${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Read models from JSON file
    local model_count=$(jq '. | length' "$MODELS_CONFIG")
    local available_index=1
    
    # Create a mapping between display numbers and actual indices
    AVAILABLE_INDICES=()
    
    for ((i=0; i<$model_count; i++)); do
        local name=$(jq -r ".[$i].name" "$MODELS_CONFIG")
        local model_name=$(jq -r ".[$i].model.name" "$MODELS_CONFIG")
        local version=$(jq -r ".[$i].model.version" "$MODELS_CONFIG")
        local format=$(jq -r ".[$i].model.format" "$MODELS_CONFIG")
        local sku=$(jq -r ".[$i].sku.name" "$MODELS_CONFIG")
        local capacity=$(jq -r ".[$i].sku.capacity" "$MODELS_CONFIG")
        
        # Check if already deployed
        local is_deployed=false
        for deployed in "${CURRENT_DEPLOYMENTS[@]}"; do
            if [ "$deployed" == "$name" ]; then
                is_deployed=true
                break
            fi
        done
        
        # Only show models that are NOT deployed
        if [ "$is_deployed" = false ]; then
            echo -e "${YELLOW}${available_index}. ${NC}$name"
            echo -e "   Model: $model_name (v$version)"
            echo -e "   Format: $format | SKU: $sku | Capacity: $capacity"
            echo ""
            
            AVAILABLE_INDICES+=($i)
            available_index=$((available_index + 1))
        fi
    done
    
    if [ ${#AVAILABLE_INDICES[@]} -eq 0 ]; then
        echo -e "${YELLOW}No additional models available - all models are already deployed!${NC}"
        echo ""
        exit 0
    fi
}

select_models() {
    echo -e "${YELLOW}Select models to deploy (enter numbers separated by spaces, e.g., '1 3 5'):${NC}"
    echo -e "${YELLOW}Or type 'all' to deploy all available models, or 'cancel' to exit:${NC}"
    read -p "> " selection
    
    if [ "$selection" == "cancel" ]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
    
    SELECTED_INDICES=()
    
    if [ "$selection" == "all" ]; then
        # Select all available (non-deployed) models
        for index in "${AVAILABLE_INDICES[@]}"; do
            SELECTED_INDICES+=($index)
        done
    else
        # Parse selected numbers and map to actual indices
        for num in $selection; do
            local array_pos=$((num-1))
            
            if [ $array_pos -ge 0 ] && [ $array_pos -lt ${#AVAILABLE_INDICES[@]} ]; then
                local actual_index=${AVAILABLE_INDICES[$array_pos]}
                SELECTED_INDICES+=($actual_index)
            else
                log_warning "Invalid selection: $num (skipped)"
            fi
        done
    fi
    
    if [ ${#SELECTED_INDICES[@]} -eq 0 ]; then
        log_error "No valid models selected"
        exit 1
    fi
}

build_deployment_array() {
    echo ""
    log_info "Building deployment configuration..."
    
    # Get existing additional model deployments from environment
    local existing_deployments="${ADDITIONAL_MODEL_DEPLOYMENTS:-[]}"
    
    # Validate it's valid JSON
    if ! echo "$existing_deployments" | jq empty 2>/dev/null; then
        existing_deployments="[]"
    fi
    
    # Start with existing deployments (or empty array if none)
    if [ "$existing_deployments" = "[]" ] || [ -z "$existing_deployments" ]; then
        DEPLOYMENT_JSON="["
        local first=true
    else
        # Remove the closing bracket from existing deployments to append new ones
        DEPLOYMENT_JSON="${existing_deployments%]}"
        local first=false
    fi
    
    # Add new selected models
    for index in "${SELECTED_INDICES[@]}"; do
        local name=$(jq -r ".[$index].name" "$MODELS_CONFIG")
        local model_name=$(jq -r ".[$index].model.name" "$MODELS_CONFIG")
        local model_version=$(jq -r ".[$index].model.version" "$MODELS_CONFIG")
        local model_format=$(jq -r ".[$index].model.format" "$MODELS_CONFIG")
        local sku_name=$(jq -r ".[$index].sku.name" "$MODELS_CONFIG")
        local capacity=$(jq -r ".[$index].sku.capacity" "$MODELS_CONFIG")
        
        # Add comma separator if not first entry
        if [ "$first" = false ]; then
            DEPLOYMENT_JSON+=","
        fi
        first=false
        
        # Build JSON object for this deployment
        DEPLOYMENT_JSON+="{\"name\":\"$name\",\"model\":{\"format\":\"$model_format\",\"name\":\"$model_name\",\"version\":\"$model_version\"},\"sku\":{\"name\":\"$sku_name\",\"capacity\":$capacity}}"
        
        log_info "  Adding: $name ($model_name v$model_version)"
    done
    
    DEPLOYMENT_JSON+="]"
    
    # Validate the JSON
    if ! echo "$DEPLOYMENT_JSON" | jq empty 2>/dev/null; then
        log_error "Generated invalid JSON configuration"
        log_error "JSON: $DEPLOYMENT_JSON"
        exit 1
    fi
    
    log_success "Deployment configuration built"
}

deploy_additional_models() {
    echo ""
    log_info "Deploying additional models..."
    
    # Create parameters file for the deployment
    local params_file=$(mktemp)
    cat > "$params_file" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "accountName": {
      "value": "$AI_ACCOUNT_NAME"
    },
    "modelDeployments": {
      "value": $DEPLOYMENT_JSON
    }
  }
}
EOF
    
    log_info "Deployment parameters:"
    cat "$params_file" | jq '.'
    
    log_warning "This will deploy the selected models to your Azure AI Services account."
    log_info "Running: az deployment group create"
    echo ""
    
    # Deploy using Azure CLI directly
    local template_file="$SCRIPT_DIR/customization/add-models.bicep"
    
    if az deployment group create \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --template-file "$template_file" \
        --parameters "@$params_file" \
        --name "additional-models-$(date +%Y%m%d-%H%M%S)"; then
        
        log_success "Additional models deployed successfully!"
        
        # Update the .env file with the new deployment configuration
        update_env_file
    else
        log_error "Failed to deploy additional models"
        rm -f "$params_file"
        exit 1
    fi
    
    rm -f "$params_file"
}

update_env_file() {
    log_info "Updating .env file with deployment configuration..."
    
    # Create a backup of the .env file
    local backup_file="${ENV_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$ENV_FILE" "$backup_file"
    log_info "Created backup: ${backup_file##*/}"
    
    # Check if ADDITIONAL_MODEL_DEPLOYMENTS already exists in .env
    if grep -q "^ADDITIONAL_MODEL_DEPLOYMENTS=" "$ENV_FILE"; then
        # Update existing line
        # Use a temporary file to avoid issues with sed on different platforms
        local temp_file=$(mktemp)
        awk -v deployment="$DEPLOYMENT_JSON" '
        /^ADDITIONAL_MODEL_DEPLOYMENTS=/ {
            print "ADDITIONAL_MODEL_DEPLOYMENTS=" deployment
            next
        }
        {print}
        ' "$ENV_FILE" > "$temp_file"
        mv "$temp_file" "$ENV_FILE"
        log_success "Updated ADDITIONAL_MODEL_DEPLOYMENTS in .env file"
    else
        # Append new line
        echo "" >> "$ENV_FILE"
        echo "# Additional Model Deployments (added by 2-add-model-choices.sh)" >> "$ENV_FILE"
        echo "ADDITIONAL_MODEL_DEPLOYMENTS=$DEPLOYMENT_JSON" >> "$ENV_FILE"
        log_success "Added ADDITIONAL_MODEL_DEPLOYMENTS to .env file"
    fi
    
    # Reload the environment to pick up changes
    source "$ENV_FILE"
}

display_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Deployment Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    for index in "${SELECTED_INDICES[@]}"; do
        local name=$(jq -r ".[$index].name" "$MODELS_CONFIG")
        echo -e "${GREEN}✓ $name deployed${NC}"
    done
    
    echo -e "${GREEN}========================================${NC}"
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Add Additional Model Deployments${NC}"
    echo -e "${BLUE}  (Using .env file)${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    check_prerequisites
    get_ai_account_name
    get_current_deployments
    display_deployed_models
    display_available_models
    select_models
    build_deployment_array
    deploy_additional_models
    display_summary
    
    echo ""
    log_success "Model deployment completed successfully!"
    echo ""
    log_info "Note: The .env file has been updated. You may want to reload it:"
    log_info "  source $ENV_FILE"
}

# Run main function
main
