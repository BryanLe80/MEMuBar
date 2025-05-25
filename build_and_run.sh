#!/bin/bash

# JustAMemBar - Build and Run Script
# This script builds the project and runs the app for easy testing

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="JustAMemBar"
SCHEME_NAME="JustAMemBar"
CONFIGURATION="Debug"

# Derived data path (will be determined dynamically)
DERIVED_DATA_PATH=""

echo -e "${BLUE}🔨 Building and Running JustAMemBar${NC}"
echo "=================================="

# Function to find derived data path
find_derived_data_path() {
    echo -e "${YELLOW}📁 Finding build products...${NC}"
    
    # Try to find the derived data path
    local search_path="$HOME/Library/Developer/Xcode/DerivedData"
    local project_derived_data=$(find "$search_path" -name "*JustAMemBar*" -type d -maxdepth 1 | head -1)
    
    if [ -n "$project_derived_data" ]; then
        DERIVED_DATA_PATH="$project_derived_data/Build/Products/$CONFIGURATION"
        echo -e "${GREEN}✅ Found build products at: $DERIVED_DATA_PATH${NC}"
    else
        echo -e "${RED}❌ Could not find derived data path${NC}"
        exit 1
    fi
}

# Function to clean build
clean_build() {
    echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
    xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" clean
    echo -e "${GREEN}✅ Clean completed${NC}"
}

# Function to build project
build_project() {
    echo -e "${YELLOW}🔨 Building project...${NC}"
    
    if xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" build; then
        echo -e "${GREEN}✅ Build succeeded${NC}"
        return 0
    else
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    fi
}

# Function to run the app
run_app() {
    find_derived_data_path
    
    local app_path="$DERIVED_DATA_PATH/$PROJECT_NAME.app"
    
    if [ -d "$app_path" ]; then
        echo -e "${YELLOW}🚀 Launching app...${NC}"
        open "$app_path"
        echo -e "${GREEN}✅ App launched${NC}"
        
        # Wait a moment then show logs
        echo -e "${BLUE}📋 Showing XPC logs (press Ctrl+C to stop):${NC}"
        sleep 2
        log stream --predicate 'subsystem CONTAINS "First.JustAMemBar" OR subsystem CONTAINS "First.MemBarHelper"' --level debug --style compact
    else
        echo -e "${RED}❌ App not found at: $app_path${NC}"
        exit 1
    fi
}

# Function to kill existing app instances
kill_existing_app() {
    echo -e "${YELLOW}🔄 Checking for existing app instances...${NC}"
    
    local pids=$(pgrep -f "$PROJECT_NAME" || true)
    if [ -n "$pids" ]; then
        echo -e "${YELLOW}🛑 Killing existing app instances...${NC}"
        pkill -f "$PROJECT_NAME" || true
        sleep 1
        echo -e "${GREEN}✅ Existing instances terminated${NC}"
    else
        echo -e "${GREEN}✅ No existing instances found${NC}"
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --clean     Clean build before building"
    echo "  -r, --run-only  Skip build and just run the app"
    echo "  -l, --logs-only Show logs without building or running"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Build and run"
    echo "  $0 --clean      # Clean, build, and run"
    echo "  $0 --run-only   # Just run the existing build"
    echo "  $0 --logs-only  # Just show logs"
}

# Parse command line arguments
CLEAN_BUILD=false
RUN_ONLY=false
LOGS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -r|--run-only)
            RUN_ONLY=true
            shift
            ;;
        -l|--logs-only)
            LOGS_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    # Change to script directory
    cd "$(dirname "$0")"
    
    if [ "$LOGS_ONLY" = true ]; then
        echo -e "${BLUE}📋 Showing XPC logs (press Ctrl+C to stop):${NC}"
        log stream --predicate 'subsystem CONTAINS "First.JustAMemBar" OR subsystem CONTAINS "First.MemBarHelper"' --level debug --style compact
        exit 0
    fi
    
    # Kill existing instances
    kill_existing_app
    
    if [ "$RUN_ONLY" = false ]; then
        # Build the project
        if [ "$CLEAN_BUILD" = true ]; then
            clean_build
        fi
        
        if ! build_project; then
            echo -e "${RED}❌ Build failed. Exiting.${NC}"
            exit 1
        fi
    fi
    
    # Run the app
    run_app
}

# Trap Ctrl+C to clean up
trap 'echo -e "\n${YELLOW}🛑 Script interrupted${NC}"; exit 0' INT

# Run main function
main 