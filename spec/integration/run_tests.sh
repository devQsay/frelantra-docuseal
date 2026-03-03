#!/bin/bash

# DocuSeal API Integration Test Runner
# This script helps run the API integration tests with proper configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   DocuSeal API Integration Test Runner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}\n"

# Check if .env.test exists
if [ ! -f "$SCRIPT_DIR/.env.test" ]; then
    echo -e "${RED}✗ Error: .env.test file not found${NC}\n"
    echo -e "${YELLOW}Please create a .env.test file with your configuration:${NC}"
    echo -e "  1. Copy the example: ${GREEN}cp $SCRIPT_DIR/.env.test.example $SCRIPT_DIR/.env.test${NC}"
    echo -e "  2. Edit .env.test and add your API token"
    echo -e "  3. Run this script again\n"
    exit 1
fi

# Load environment variables
echo -e "${BLUE}→${NC} Loading configuration from .env.test..."
set -a
source "$SCRIPT_DIR/.env.test"
set +a

# Verify required variables
if [ -z "$API_TEST_TOKEN" ] || [ "$API_TEST_TOKEN" = "your_api_token_here" ]; then
    echo -e "${RED}✗ Error: API_TEST_TOKEN not configured${NC}\n"
    echo -e "${YELLOW}Please edit $SCRIPT_DIR/.env.test and set your API token${NC}\n"
    exit 1
fi

if [ "$RUN_API_INTEGRATION_TESTS" != "true" ]; then
    echo -e "${YELLOW}⚠ Warning: RUN_API_INTEGRATION_TESTS is not set to 'true'${NC}"
    echo -e "${YELLOW}Tests will be skipped. Set RUN_API_INTEGRATION_TESTS=true to enable.${NC}\n"
fi

# Set defaults
API_TEST_BASE_URL="${API_TEST_BASE_URL:-http://alb-docuseal-frelantra-1719079990.us-east-1.elb.amazonaws.com}"
API_TEST_TIMEOUT="${API_TEST_TIMEOUT:-30}"

echo -e "${GREEN}✓${NC} Configuration loaded"
echo -e "  Base URL: ${BLUE}$API_TEST_BASE_URL${NC}"
echo -e "  Timeout: ${BLUE}${API_TEST_TIMEOUT}s${NC}"
echo -e "  Tests enabled: ${BLUE}$RUN_API_INTEGRATION_TESTS${NC}\n"

# Test API connectivity
echo -e "${BLUE}→${NC} Testing API connectivity..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Auth-Token: $API_TEST_TOKEN" \
    "$API_TEST_BASE_URL/api/templates?limit=1" \
    --max-time 10)

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✓${NC} API is accessible and token is valid\n"
elif [ "$HTTP_STATUS" = "401" ]; then
    echo -e "${RED}✗ Error: Invalid API token (HTTP 401)${NC}\n"
    exit 1
else
    echo -e "${YELLOW}⚠ Warning: Unexpected response (HTTP $HTTP_STATUS)${NC}"
    echo -e "${YELLOW}Continuing anyway...${NC}\n"
fi

# Parse command line arguments
TEST_FILE=""
TEST_FORMAT="documentation"
EXTRA_ARGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --submissions)
            TEST_FILE="$SCRIPT_DIR/submissions_integration_spec.rb"
            shift
            ;;
        --submitters)
            TEST_FILE="$SCRIPT_DIR/submitters_integration_spec.rb"
            shift
            ;;
        --templates)
            TEST_FILE="$SCRIPT_DIR/templates_integration_spec.rb"
            shift
            ;;
        --progress)
            TEST_FORMAT="progress"
            shift
            ;;
        --quiet)
            TEST_FORMAT="progress"
            shift
            ;;
        --verbose)
            TEST_FORMAT="documentation"
            EXTRA_ARGS="$EXTRA_ARGS --format documentation"
            shift
            ;;
        *)
            EXTRA_ARGS="$EXTRA_ARGS $1"
            shift
            ;;
    esac
done

# Change to project root
cd "$PROJECT_ROOT"

# Run the tests
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Running Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}\n"

if [ -z "$TEST_FILE" ]; then
    echo -e "${BLUE}→${NC} Running all integration tests...\n"
    bundle exec rspec "$SCRIPT_DIR/" --format "$TEST_FORMAT" $EXTRA_ARGS
else
    echo -e "${BLUE}→${NC} Running $(basename $TEST_FILE)...\n"
    bundle exec rspec "$TEST_FILE" --format "$TEST_FORMAT" $EXTRA_ARGS
fi

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✓ All tests passed!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}═══════════════════════════════════════════════════${NC}"
    echo -e "${RED}   ✗ Some tests failed${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════${NC}"
fi

exit $EXIT_CODE
