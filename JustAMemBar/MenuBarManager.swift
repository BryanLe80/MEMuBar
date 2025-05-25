//
//  MenuBarManager.swift
//  JustAMemBar
//
//  Created by Bryan Le on 5/24/25.
//

import SwiftUI
import AppKit
import os.log

// Import the XPC components (these should be available from the same target)
// Note: If these still show errors in linter but build succeeds, it's likely a target membership issue

class MenuBarManager: NSObject, ObservableObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var xpcClient: MemBarXPCClient?  // Will be set up later when XPC framework is available
    private var updateTimer: Timer?
    private let logger = Logger(subsystem: "First.JustAMemBar", category: "MenuBar")
    
    // Memory statistics
    @Published var memoryPressure: String = "Loading..."
    @Published var memoryUsed: String = "Loading..."
    @Published var swapUsed: String = "Loading..."
    @Published var lastUpdated: String = "Never"
    
    // Enhanced pressure tracking
    @Published var overallPressureScore: Double = 0.0
    @Published var memoryUsagePercentage: Double = 0.0
    @Published var swapUsagePercentage: Double = 0.0
    
    // Settings - Optimized for battery efficiency
    @Published var refreshInterval: TimeInterval = 5.0  // Increased from 2s to 5s per OptimizeBattMem.md
    @Published var isAutoRefreshEnabled: Bool = true
    
    // Real-time update settings
    private let focusedRefreshInterval: TimeInterval = 1.0  // Fast updates when menu is open
    private var isFocused: Bool = false
    
    // Optimization: Track last values to avoid unnecessary UI updates
    private var lastMemoryPressure: String = ""
    private var lastMemoryUsed: String = ""
    private var lastSwapUsed: String = ""
    private var lastOverallPressureScore: Double = -1.0
    

    
    override init() {
        super.init()
        
        // Set activation policy for menu bar app (no dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)
        

        
        setupMenuBar()
        setupXPCClient()
        setupFocusNotifications()
        startAutoRefresh()
        
        logger.info("MenuBarManager initialized")
    }
    
    deinit {
        cleanup()
    }
    
    private func setupMenuBar() {
        // Create status item with wider length for the enhanced battery-like icon
        statusItem = NSStatusBar.system.statusItem(withLength: 32)
        
        guard let statusItem = statusItem else {
            logger.error("Failed to create status item")
            return
        }
        
        // Configure button with SF Symbol
        if let button = statusItem.button {
            // Use memory chip SF Symbol for clean, professional appearance
            if let image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory Status") {
                image.isTemplate = true  // Ensures proper menu bar integration
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                // Fallback for older systems
                button.title = "⚡"
            }
            
            button.toolTip = "MemBar - Memory Statistics"
            
            // Apply subtle visual feedback
            button.bezelStyle = .regularSquare
        }
        
        // Create and set menu
        updateMenu()
        
        logger.info("Menu bar setup completed with clean design")
    }
    
    private func setupXPCClient() {
        xpcClient = MemBarXPCClient()
        logger.info("XPC client setup completed")
    }
    
    private func setupFocusNotifications() {
        // Observe when app becomes active/inactive
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        logger.info("Focus notifications setup completed")
    }
    
    private func updateMenu() {
        if isFocused {
            logger.info("Updating menu during live session - Memory: \(self.memoryUsed)")
        }
        let menu = NSMenu()
        
        // Clean title with system styling
        let titleItem = NSMenuItem(title: "MemBar", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        
        // Apply system secondary label color for subtle appearance
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        titleItem.attributedTitle = NSAttributedString(string: "MemBar", attributes: titleAttributes)
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Memory statistics with clean layout
        addMemoryStatisticsSection(to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Control section with SF Symbols
        addControlSection(to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings submenu
        addSettingsSection(to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Application section
        addApplicationSection(to: menu)
        
        // Set menu delegate for real-time updates when menu is open
        menu.delegate = self
        statusItem?.menu = menu
    }
    
    private func addMemoryStatisticsSection(to menu: NSMenu) {
        // Memory pressure with visual indicator
        let pressureItem = createStatItem(
            label: "System Pressure",
            value: memoryPressure,
            color: getColorForMemoryPressure(memoryPressure)
        )
        menu.addItem(pressureItem)
        
        // Memory used - with breakdown
        let usedItem = createStatItem(label: "Mem Used", value: memoryUsed)
        menu.addItem(usedItem)
        
        // Swap memory - with consistent formatting
        let swapItem = createStatItem(label: "Swap", value: swapUsed)
        menu.addItem(swapItem)
        
        // Last updated with subtle styling
        let updatedItem = NSMenuItem(title: "Updated \(lastUpdated)", action: nil, keyEquivalent: "")
        updatedItem.isEnabled = false
        let updatedAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        updatedItem.attributedTitle = NSAttributedString(string: "Updated \(lastUpdated)", attributes: updatedAttributes)
        menu.addItem(updatedItem)
    }
    
    private func addControlSection(to menu: NSMenu) {
        // Refresh manually with SF Symbol
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshManually), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        menu.addItem(refreshItem)
        
        // Auto-refresh toggle
        let autoRefreshItem = NSMenuItem(
            title: isAutoRefreshEnabled ? "Pause Auto-Refresh" : "Resume Auto-Refresh",
            action: #selector(toggleAutoRefresh),
            keyEquivalent: ""
        )
        autoRefreshItem.target = self
        autoRefreshItem.image = NSImage(
            systemSymbolName: isAutoRefreshEnabled ? "pause.circle" : "play.circle",
            accessibilityDescription: isAutoRefreshEnabled ? "Pause" : "Resume"
        )
        menu.addItem(autoRefreshItem)
    }
    
    private func addSettingsSection(to menu: NSMenu) {
        // Refresh interval submenu
        let intervalItem = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
        intervalItem.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer")
        
        let intervalSubmenu = NSMenu()
        // Battery-optimized intervals per OptimizeBattMem.md (removed very aggressive 1-2s options)
        let intervals: [(title: String, interval: TimeInterval)] = [
            ("3 seconds", 3.0),
            ("5 seconds (Recommended)", 5.0),
            ("10 seconds", 10.0),
            ("30 seconds", 30.0),
            ("60 seconds", 60.0)
        ]
        
        for (title, interval) in intervals {
            let item = NSMenuItem(title: title, action: #selector(setRefreshInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            item.state = (interval == refreshInterval) ? .on : .off
            intervalSubmenu.addItem(item)
        }
        
        intervalItem.submenu = intervalSubmenu
        menu.addItem(intervalItem)
    }
    
    private func addApplicationSection(to menu: NSMenu) {
        // About with clean styling
        let aboutItem = NSMenuItem(title: "About MemBar", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        menu.addItem(aboutItem)
        
        // Quit with standard shortcut
        let quitItem = NSMenuItem(title: "Quit MemBar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func createStatItem(label: String, value: String, color: NSColor? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: "\(label): \(value)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        
        // Create attributed string with proper typography
        let fullText = "\(label): \(value)"
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // Style the label
        let labelRange = NSRange(location: 0, length: label.count)
        attributedString.addAttributes([
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ], range: labelRange)
        
        // Style the value
        let valueRange = NSRange(location: label.count + 2, length: value.count)
        let valueColor = color ?? NSColor.secondaryLabelColor
        attributedString.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: valueColor
        ], range: valueRange)
        
        item.attributedTitle = attributedString
        return item
    }
    
    private func startAutoRefresh() {
        guard isAutoRefreshEnabled else { return }
        
        updateTimer?.invalidate()
        
        // Use focused interval if app is focused, otherwise use normal interval
        let currentInterval = isFocused ? focusedRefreshInterval : refreshInterval
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            // Use utility QoS for background data fetching per OptimizeBattMem.md
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.fetchMemoryStatistics()
            }
        }
        
        // Initial fetch
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.fetchMemoryStatistics()
        }
        
        logger.info("Auto-refresh started with interval: \(currentInterval)s (focused: \(self.isFocused))")
    }
    
    private func stopAutoRefresh() {
        updateTimer?.invalidate()
        updateTimer = nil
        logger.info("Auto-refresh stopped")
    }
    
    private func fetchMemoryStatistics() {
        logger.debug("Fetching memory statistics...")
        
        xpcClient?.getMemoryStatistics { [weak self] (memoryData: MemoryData?, error: Error?) in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var hasSignificantChange = false
                
                if let error = error {
                    self.logger.error("Failed to fetch memory statistics: \(error.localizedDescription)")
                    if self.memoryPressure != "Error" {
                        self.memoryPressure = "Error"
                        self.memoryUsed = "Unknown"
                        self.swapUsed = "Unknown"
                        self.overallPressureScore = 0.0
                        self.memoryUsagePercentage = 0.0
                        self.swapUsagePercentage = 0.0
                        hasSignificantChange = true
                    }
                } else if let data = memoryData {
                    // Check for significant changes before updating UI (per OptimizeBattMem.md)
                    if self.lastMemoryPressure != data.memoryPressure ||
                       self.lastMemoryUsed != data.memoryUsed ||
                       self.lastSwapUsed != data.swapUsed {
                        hasSignificantChange = true
                    }
                    
                    self.memoryPressure = data.memoryPressure
                    self.memoryUsed = data.memoryUsed
                    self.swapUsed = data.swapUsed
                    self.lastUpdated = self.getCurrentTimeString()
                    
                    // Calculate enhanced pressure metrics
                    self.calculateEnhancedPressureMetrics(data: data)
                    
                    // Check if overall pressure changed significantly (>2% change for better responsiveness)
                    if abs(self.overallPressureScore - self.lastOverallPressureScore) > 2.0 {
                        hasSignificantChange = true
                    }
                    
                    // Update tracking values
                    self.lastMemoryPressure = data.memoryPressure
                    self.lastMemoryUsed = data.memoryUsed
                    self.lastSwapUsed = data.swapUsed
                    self.lastOverallPressureScore = self.overallPressureScore
                    
                    if self.isFocused {
                        self.logger.info("Live update - Memory: \(data.memoryUsed), Pressure: \(data.memoryPressure)")
                    } else {
                        self.logger.debug("Memory statistics updated: \(data.memoryPressure), \(data.memoryUsed), \(data.swapUsed)")
                    }
                } else {
                    self.logger.error("No memory data received")
                    if self.memoryPressure != "Unknown" {
                        self.memoryPressure = "Unknown"
                        self.memoryUsed = "Unknown"
                        self.swapUsed = "Unknown"
                        self.overallPressureScore = 0.0
                        self.memoryUsagePercentage = 0.0
                        self.swapUsagePercentage = 0.0
                        hasSignificantChange = true
                    }
                }
                

                
                // Always update icon for better user feedback
                self.updateMenuBarIcon()
                
                // Update menu more frequently when focused for live updating
                if hasSignificantChange || self.isFocused {
                    self.updateMenu()
                }
            }
        }
    }
    
    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
    
    private func calculateEnhancedPressureMetrics(data: MemoryData) {
        // Parse memory usage percentage from the memory used string
        self.memoryUsagePercentage = parseMemoryPercentage(from: data.memoryUsed)
        
        // Parse swap usage - convert to percentage based on typical swap sizes
        self.swapUsagePercentage = parseSwapPercentage(from: data.swapUsed)
        
        // Calculate overall pressure score (0-100%)
        let pressureScore = systemPressureToScore(data.memoryPressure)
        
        // Weighted calculation:
        // - Memory usage: 40% weight
        // - Swap usage: 30% weight  
        // - System pressure: 30% weight
        self.overallPressureScore = (self.memoryUsagePercentage * 0.4) + 
                                   (self.swapUsagePercentage * 0.3) + 
                                   (pressureScore * 0.3)
        
        logger.debug("Enhanced pressure metrics - Memory: \(self.memoryUsagePercentage)%, Swap: \(self.swapUsagePercentage)%, Overall: \(self.overallPressureScore)%")
    }
    
    private func parseMemoryPercentage(from memoryString: String) -> Double {
        // Extract numbers from strings like "8.5 GB" or "4.2 GB of 16 GB"
        let components = memoryString.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let numbers = components.compactMap { Double($0) }.filter { $0 > 0 }
        
        if numbers.count >= 2 {
            // Format: "used of total"
            let used = numbers[0]
            let total = numbers[1]
            return min(100.0, (used / total) * 100.0)
        } else if numbers.count == 1 {
            // Estimate based on typical system memory (assuming 16GB system)
            let used = numbers[0]
            let estimatedTotal = 16.0 // GB
            return min(100.0, (used / estimatedTotal) * 100.0)
        }
        
        return 0.0
    }
    
    private func parseSwapPercentage(from swapString: String) -> Double {
        // Extract swap usage from strings like "2.1 GB" or "0 MB"
        let components = swapString.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let numbers = components.compactMap { Double($0) }.filter { $0 > 0 }
        
        guard let swapUsed = numbers.first else { return 0.0 }
        
        // Convert to GB if needed
        let swapInGB: Double
        if swapString.contains("MB") {
            swapInGB = swapUsed / 1024.0
        } else {
            swapInGB = swapUsed
        }
        
        // Calculate percentage based on typical macOS swap behavior
        // Significant swap usage indicates memory pressure
        if swapInGB == 0 {
            return 0.0
        } else if swapInGB < 1.0 {
            return 25.0 // Light swap usage
        } else if swapInGB < 4.0 {
            return 50.0 // Moderate swap usage
        } else {
            return 80.0 // Heavy swap usage
        }
    }
    
    private func systemPressureToScore(_ pressure: String) -> Double {
        switch pressure.lowercased() {
        case "normal":
            return 0.0
        case "warning":
            return 65.0
        case "critical":
            return 90.0
        default:
            return 0.0
        }
    }
    
    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        
        // Create progressively filled memory chip icon
        let filledIcon = createProgressivelyFilledMemoryChip(fillPercentage: overallPressureScore)
        
        if let filledIcon = filledIcon {
            button.image = filledIcon
        } else {
            // Fallback to text if custom icon generation fails
            button.title = getPressureEmoji(overallPressureScore)
        }
        
        // Enhanced tooltip with raw data breakdown
        let pressureEmoji = getPressureEmoji(overallPressureScore)
        let fillDescription = String(format: "%.0f", overallPressureScore)
        button.toolTip = "MemBar \(pressureEmoji) Memory \(fillDescription)% filled\n• Memory: \(memoryUsed)\n• Swap: \(swapUsed)\n• System: \(memoryPressure)"
    }
    
    private func getColorForMemoryPressure(_ pressure: String) -> NSColor {
        switch pressure.lowercased() {
        case "normal":
            return NSColor.systemGreen
        case "warning":
            return NSColor.systemOrange  
        case "critical":
            return NSColor.systemRed
        default:
            return NSColor.controlAccentColor
        }
    }
    
    private func getEnhancedColorForPressure(_ pressureScore: Double) -> NSColor {
        switch pressureScore {
        case 0..<10:
            // Bright green for very low pressure (0-9%)
            return NSColor.systemGreen
        case 10..<25:
            // Green for low pressure (10-24%)
            return NSColor.systemGreen
        case 25..<40:
            // Light green for low-medium pressure (25-39%)
            return NSColor(hue: 120.0/360.0, saturation: 0.6, brightness: 0.8, alpha: 1.0)
        case 40..<55:
            // Yellow-green for medium pressure (40-54%)
            return NSColor(hue: 80.0/360.0, saturation: 0.8, brightness: 0.8, alpha: 1.0)
        case 55..<70:
            // Yellow for medium-high pressure (55-69%)
            return NSColor.systemYellow
        case 70..<80:
            // Orange for high pressure (70-79%)
            return NSColor.systemOrange
        case 80..<90:
            // Red-orange for very high pressure (80-89%)
            return NSColor(hue: 15.0/360.0, saturation: 0.9, brightness: 0.8, alpha: 1.0)
        case 90...100:
            // Bright red for critical pressure (90-100%)
            return NSColor.systemRed
        default:
            return NSColor.controlAccentColor
        }
    }
    
    private func getGradientColorForPercentage(_ percentage: Double) -> NSColor {
        // Clamp percentage to 0-100 range
        let clampedPercentage = max(0, min(100, percentage))
        
        // Convert to 0-1 range for interpolation
        let normalizedValue = CGFloat(clampedPercentage / 100.0)
        
        // Define green and yellow in HSB for smooth interpolation
        let greenHue: CGFloat = 120.0 / 360.0  // Green
        let yellowHue: CGFloat = 60.0 / 360.0  // Yellow
        let saturation: CGFloat = 0.8
        let brightness: CGFloat = 0.9
        
        // Interpolate between green and yellow hue
        let interpolatedHue = greenHue + (yellowHue - greenHue) * normalizedValue
        
        return NSColor(hue: interpolatedHue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }
    
    private func getContrastAwareGradientColor(_ percentage: Double) -> NSColor {
        // Clamp percentage to 0-100 range
        let clampedPercentage = max(0, min(100, percentage))
        
        // Enhanced smooth gradient with more color stops for better progression
        switch clampedPercentage {
        case 0..<5:
            // Very bright green for minimal usage
            return NSColor(hue: 120.0/360.0, saturation: 0.8, brightness: 0.95, alpha: 1.0)
        case 5..<15:
            // Bright green for low usage
            return NSColor(hue: 115.0/360.0, saturation: 0.85, brightness: 0.9, alpha: 1.0)
        case 15..<30:
            // Green for normal usage
            return NSColor(hue: 110.0/360.0, saturation: 0.9, brightness: 0.85, alpha: 1.0)
        case 30..<50:
            // Yellow-green transition
            let normalized = CGFloat((clampedPercentage - 30) / 20)  // 0-1 range within this bracket
            let hue = 110.0/360.0 + (85.0/360.0 - 110.0/360.0) * normalized
            return NSColor(hue: hue, saturation: 0.9, brightness: 0.85, alpha: 1.0)
        case 50..<70:
            // Yellow to orange transition
            let normalized = CGFloat((clampedPercentage - 50) / 20)
            let hue = 85.0/360.0 + (45.0/360.0 - 85.0/360.0) * normalized
            return NSColor(hue: hue, saturation: 0.95, brightness: 0.85, alpha: 1.0)
        case 70..<85:
            // Orange transition
            let normalized = CGFloat((clampedPercentage - 70) / 15)
            let hue = 45.0/360.0 + (25.0/360.0 - 45.0/360.0) * normalized
            return NSColor(hue: hue, saturation: 0.95, brightness: 0.85, alpha: 1.0)
        case 85...100:
            // Red for high/critical usage
            return NSColor(hue: 15.0/360.0, saturation: 0.95, brightness: 0.85, alpha: 1.0)
        default:
            // Fallback bright green
            return NSColor(hue: 120.0/360.0, saturation: 0.8, brightness: 0.95, alpha: 1.0)
        }
    }
    

    
    private func getPressureEmoji(_ pressureScore: Double) -> String {
        switch pressureScore {
        case 0..<15:
            return "🟢"  // Very low pressure
        case 15..<30:
            return "🟢"  // Low pressure
        case 30..<45:
            return "🟡"  // Low-medium pressure
        case 45..<60:
            return "🟡"  // Medium pressure
        case 60..<75:
            return "🟠"  // Medium-high pressure
        case 75..<85:
            return "🔴"  // High pressure
        case 85...100:
            return "🔴"  // Critical pressure
        default:
            return "⚡"
        }
    }
    
    private func createProgressivelyFilledMemoryChip(fillPercentage: Double) -> NSImage? {
        // Define wider battery-like icon size for better Apple UI design language compliance (28x18 points)
        let iconSize = NSSize(width: 28, height: 18)
        
        // Create high-quality symbol configuration for better scaling
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium, scale: .large)
        
        // Verify that the memory chip icon is available
        guard NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory Chip") != nil else {
            return nil
        }
        
        // Create a new image with the desired size
        let filledImage = NSImage(size: iconSize)
        
        filledImage.lockFocus()
        defer { filledImage.unlockFocus() }
        
        // Get graphics context
        guard let context = NSGraphicsContext.current?.cgContext else { return nil }
        
        // Clear the context with transparent background
        context.clear(CGRect(origin: .zero, size: iconSize))
        
        // Create the "inside" fill area with larger bars (reduced inset for more prominent fill)
        let insetAmount: CGFloat = 3.5  // Slightly increased for better visual balance
        let insideRect = NSRect(
            x: insetAmount,
            y: insetAmount,
            width: iconSize.width - (insetAmount * 2),
            height: iconSize.height - (insetAmount * 2)
        )
        
        // Enhanced progressive filling with smoother segments
        let segmentCount = 10  // More granular segments for smoother progression
        let segmentWidth = insideRect.width / CGFloat(segmentCount)
        let segmentsToFill = Int(ceil(fillPercentage / 10.0))  // Number of full segments to fill
        
        // Draw filled segments with gradient effect
        for segment in 0..<min(segmentsToFill, segmentCount) {
            let segmentRect = NSRect(
                x: insideRect.origin.x + (CGFloat(segment) * segmentWidth),
                y: insideRect.origin.y,
                width: segmentWidth - 0.5,  // Small gap between segments
                height: insideRect.height
            )
            
            // Calculate intensity for this segment (brighter for recent segments)
            let segmentIntensity = 1.0 - (Double(segmentsToFill - segment - 1) * 0.1)
            let adjustedPercentage = fillPercentage * segmentIntensity
            
            let fillColor = getContrastAwareGradientColor(adjustedPercentage)
            fillColor.setFill()
            
            // Draw segment with subtle rounded corners
            let segmentPath = NSBezierPath(roundedRect: segmentRect, xRadius: 1.0, yRadius: 1.0)
            segmentPath.fill()
        }
        
        // Draw partial fill for the current segment if needed
        let partialFill = fillPercentage.truncatingRemainder(dividingBy: 10.0)
        if partialFill > 0 && segmentsToFill < segmentCount {
            let partialRect = NSRect(
                x: insideRect.origin.x + (CGFloat(segmentsToFill) * segmentWidth),
                y: insideRect.origin.y,
                width: (segmentWidth - 0.5) * CGFloat(partialFill / 10.0),
                height: insideRect.height
            )
            
            let partialColor = getContrastAwareGradientColor(fillPercentage)
            partialColor.withAlphaComponent(0.7).setFill()  // Slightly transparent for partial fills
            
            let partialPath = NSBezierPath(roundedRect: partialRect, xRadius: 1.0, yRadius: 1.0)
            partialPath.fill()
        }
        
        // Draw the memory chip outline with programmatically determined colors
        if let outlineIcon = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory Chip")?.withSymbolConfiguration(symbolConfig) {
            // Use fixed color #37474F for consistent appearance on both light and dark menu bars
            let outlineColor = NSColor(red: 0x37/255.0, green: 0x47/255.0, blue: 0x4F/255.0, alpha: 1.0)
            outlineColor.setStroke()
            
            // Create a template version and tint it appropriately
            outlineIcon.lockFocus()
            outlineColor.set()
            let imageRect = NSRect(origin: .zero, size: outlineIcon.size)
            imageRect.fill(using: .sourceAtop)
            outlineIcon.unlockFocus()
            
            outlineIcon.draw(in: NSRect(origin: .zero, size: iconSize), 
                           from: NSRect.zero, 
                           operation: .sourceOver, 
                           fraction: 1.0)
        }
        
        // Set as template to preserve the automatic color inversion for the outline
        filledImage.isTemplate = false  // Keep false to preserve our custom fill colors
        
        return filledImage
    }
    
    private func createMemoryChipMask(size: NSSize) -> CGImage? {
        // Create a mask image from the memory chip icon
        guard let baseIcon = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory Chip Mask") else {
            return nil
        }
        
        let maskImage = NSImage(size: size)
        maskImage.lockFocus()
        defer { maskImage.unlockFocus() }
        
        // Draw the icon in black for the mask
        NSColor.black.set()
        baseIcon.draw(in: NSRect(origin: .zero, size: size), 
                     from: NSRect.zero, 
                     operation: .sourceOver, 
                     fraction: 1.0)
        
        // Get the CGImage representation
        guard let imageRep = maskImage.representations.first as? NSBitmapImageRep else { return nil }
        return imageRep.cgImage
    }
    
    // MARK: - Menu Actions
    
    @objc private func refreshManually() {
        logger.info("Manual refresh triggered")
        fetchMemoryStatistics()
    }
    
    @objc private func toggleAutoRefresh() {
        isAutoRefreshEnabled.toggle()
        
        if isAutoRefreshEnabled {
            startAutoRefresh()
        } else {
            stopAutoRefresh()
        }
        
        updateMenu()
        logger.info("Auto-refresh toggled: \(self.isAutoRefreshEnabled)")
    }
    
    @objc private func setRefreshInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? TimeInterval else { return }
        
        refreshInterval = interval
        
        if isAutoRefreshEnabled {
            startAutoRefresh()
        }
        
        updateMenu()
        logger.info("Refresh interval changed to: \(interval)s")
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MemBar"
        alert.informativeText = """
        A minimal macOS menu bar application for memory monitoring.
        
        Features:
        • Real-time memory usage monitoring
        • Memory pressure detection with visual indicators
        • Swap usage tracking
        • Configurable refresh intervals
        • Energy-efficient design
        
        Built with Swift, XPC services, and native macOS technologies.
        """
        alert.alertStyle = .informational
        
        // Set custom icon if available
        if let icon = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "MemBar") {
            alert.icon = icon
        }
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        logger.info("Quit requested")
        cleanup()
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        updateTimer?.invalidate()
        updateTimer = nil
        xpcClient = nil
        statusItem = nil
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Reset tracking values to free memory
        lastMemoryPressure = ""
        lastMemoryUsed = ""
        lastSwapUsed = ""
        lastOverallPressureScore = -1.0
        
        logger.info("MenuBarManager cleanup completed with memory optimization")
    }
    
    // MARK: - Focus Management
    
    @objc private func applicationDidBecomeActive() {
        isFocused = true
        logger.debug("Application became active - switching to fast refresh")
        if isAutoRefreshEnabled {
            startAutoRefresh()
        }
    }
    
    @objc private func applicationDidResignActive() {
        isFocused = false
        logger.debug("Application resigned active - switching to normal refresh")
        if isAutoRefreshEnabled {
            startAutoRefresh()
        }
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        isFocused = true
        logger.info("Menu opened - switching to real-time updates")
        if isAutoRefreshEnabled {
            startAutoRefresh()
        }
        // Force immediate refresh when menu opens
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.fetchMemoryStatistics()
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        isFocused = false
        logger.info("Menu closed - returning to normal refresh interval")
        if isAutoRefreshEnabled {
            startAutoRefresh()
        }
    }
} 