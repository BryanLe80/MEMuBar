#!/bin/bash

# JustAMemBar - Quick Test Script
# For rapid development iteration

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Quick Test - JustAMemBar${NC}"
echo "=========================="

# Kill any existing instances
echo -e "${YELLOW}🛑 Stopping existing instances...${NC}"
pkill -f "JustAMemBar" 2>/dev/null || true

# Quick build
echo -e "${YELLOW}🔨 Building...${NC}"
if xcodebuild -project JustAMemBar.xcodeproj -scheme JustAMemBar -configuration Debug build > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Find and run the app
DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -name "*JustAMemBar*" -type d -maxdepth 1 | head -1)
APP_PATH="$DERIVED_DATA/Build/Products/Debug/JustAMemBar.app"

if [ -d "$APP_PATH" ]; then
    echo -e "${YELLOW}🚀 Launching app...${NC}"
    open "$APP_PATH"
    echo -e "${GREEN}✅ App launched - Check your menu bar!${NC}"
else
    echo -e "${RED}❌ App not found${NC}"
    exit 1
fi 