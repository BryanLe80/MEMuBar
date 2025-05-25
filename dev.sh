#!/bin/bash

# JustAMemBar - Development Helper Script
# Quick shortcuts for common development tasks

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    echo -e "${BLUE}JustAMemBar Development Helper${NC}"
    echo "=============================="
    echo ""
    echo "Quick commands:"
    echo -e "  ${GREEN}./dev.sh build${NC}      - Build the project"
    echo -e "  ${GREEN}./dev.sh run${NC}        - Build and run the app"
    echo -e "  ${GREEN}./dev.sh clean${NC}      - Clean build and run"
    echo -e "  ${GREEN}./dev.sh logs${NC}       - Show XPC logs only"
    echo -e "  ${GREEN}./dev.sh kill${NC}       - Kill running app instances"
    echo -e "  ${GREEN}./dev.sh status${NC}     - Show app status"
    echo -e "  ${GREEN}./dev.sh xcode${NC}      - Open project in Xcode"
    echo ""
    echo "Examples:"
    echo -e "  ${YELLOW}./dev.sh run${NC}        # Quick build and run"
    echo -e "  ${YELLOW}./dev.sh clean${NC}      # Clean build when having issues"
    echo -e "  ${YELLOW}./dev.sh logs${NC}       # Monitor XPC communication"
}

case "$1" in
    "build")
        echo -e "${BLUE}🔨 Building project...${NC}"
        ./build_and_run.sh --run-only
        ;;
    "run")
        echo -e "${BLUE}🚀 Building and running...${NC}"
        ./build_and_run.sh
        ;;
    "clean")
        echo -e "${BLUE}🧹 Clean build and run...${NC}"
        ./build_and_run.sh --clean
        ;;
    "logs")
        echo -e "${BLUE}📋 Showing logs...${NC}"
        ./build_and_run.sh --logs-only
        ;;
    "kill")
        echo -e "${YELLOW}🛑 Killing app instances...${NC}"
        pkill -f "JustAMemBar" || echo -e "${GREEN}✅ No instances running${NC}"
        ;;
    "status")
        echo -e "${BLUE}📊 App Status:${NC}"
        if pgrep -f "JustAMemBar" > /dev/null; then
            echo -e "${GREEN}✅ JustAMemBar is running${NC}"
            echo "PIDs: $(pgrep -f "JustAMemBar" | tr '\n' ' ')"
        else
            echo -e "${YELLOW}⚠️  JustAMemBar is not running${NC}"
        fi
        ;;
    "xcode")
        echo -e "${BLUE}🔧 Opening in Xcode...${NC}"
        open JustAMemBar.xcodeproj
        ;;
    *)
        show_help
        ;;
esac 