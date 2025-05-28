//
//  main.swift
//  MemBarHelper
//
//  Created by Bryan Le on 5/24/25.
//

import Foundation
import os.log

// Note: MemBarHelperProtocol is defined in MemBarHelperProtocol.swift 
// which should be included in both targets

class MemBarHelperService: NSObject, MemBarHelperProtocol {
    
    private let logger = Logger(subsystem: "First.MemBarHelper", category: "XPCService")
    
    func getMemoryStatistics(reply: @escaping (String, String, String) -> Void) {
        logger.info("XPC Service: getMemoryStatistics called")
        
        // Get actual memory statistics from the system
        let memoryStats = getSystemMemoryStatistics()
        
        logger.info("XPC Service: Returning data - Pressure: \(memoryStats.pressure), Used: \(memoryStats.used), Swap: \(memoryStats.swap)")
        
        reply(memoryStats.pressure, memoryStats.used, memoryStats.swap)
    }
    
    func getDetailedMemoryStatistics(reply: @escaping (String, String, String, Double, Double, Double, Double) -> Void) {
        logger.info("XPC Service: getDetailedMemoryStatistics called")
        
        // Get detailed memory statistics from the system
        let detailedStats = getDetailedSystemMemoryStatistics()
        
        logger.info("XPC Service: Returning detailed data - Pressure: \(detailedStats.pressure), Used: \(detailedStats.used), Swap: \(detailedStats.swap)")
        logger.info("XPC Service: Memory breakdown - Total: \(detailedStats.totalGB), Active: \(detailedStats.activeGB), Wired: \(detailedStats.wiredGB), Compressed: \(detailedStats.compressedGB)")
        
        reply(detailedStats.pressure, detailedStats.used, detailedStats.swap, 
              detailedStats.totalGB, detailedStats.activeGB, detailedStats.wiredGB, detailedStats.compressedGB)
    }
    
    private func getSystemMemoryStatistics() -> (pressure: String, used: String, swap: String) {
        var memoryPressure = "Unknown"
        var memoryUsed = "Unknown"
        var swapUsed = "Unknown"
        
        // Get memory pressure
        memoryPressure = getMemoryPressure()
        
        // Get memory usage statistics
        let memoryInfo = getMemoryInfo()
        memoryUsed = memoryInfo.used
        swapUsed = memoryInfo.swap
        
        return (pressure: memoryPressure, used: memoryUsed, swap: swapUsed)
    }
    
    private func getDetailedSystemMemoryStatistics() -> (pressure: String, used: String, swap: String, totalGB: Double, activeGB: Double, wiredGB: Double, compressedGB: Double) {
        var memoryPressure = "Unknown"
        var memoryUsed = "Unknown"
        var swapUsed = "Unknown"
        var totalGB: Double = 0.0
        var activeGB: Double = 0.0
        var wiredGB: Double = 0.0
        var compressedGB: Double = 0.0
        
        // Get memory pressure
        memoryPressure = getMemoryPressure()
        
        // Get detailed memory usage statistics
        let detailedInfo = getDetailedMemoryInfo()
        memoryUsed = detailedInfo.used
        swapUsed = detailedInfo.swap
        totalGB = detailedInfo.totalGB
        activeGB = detailedInfo.activeGB
        wiredGB = detailedInfo.wiredGB
        compressedGB = detailedInfo.compressedGB
        
        return (pressure: memoryPressure, used: memoryUsed, swap: swapUsed, 
                totalGB: totalGB, activeGB: activeGB, wiredGB: wiredGB, compressedGB: compressedGB)
    }
    
    private func getMemoryPressure() -> String {
        // Use system-wide memory pressure detection
        var pressureLevel: UInt32 = 0
        var size = MemoryLayout<UInt32>.size
        
        // Try to get kernel memory pressure level
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0) == 0 {
            switch pressureLevel {
            case 1:
                return "Warning"
            case 2, 3, 4:
                return "Critical"
            default:
                return "Normal"
            }
        }
        
        // Fallback: calculate pressure based on memory usage
        var physicalMemory: UInt64 = 0
        size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0) == 0 {
            var vmstat = vm_statistics64()
            var vmstatCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            
            let vmResult = withUnsafeMutablePointer(to: &vmstat) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmstatCount)
                }
            }
            
            if vmResult == KERN_SUCCESS {
                let pageSize = UInt64(vm_kernel_page_size)
                // Calculate memory components for pressure calculation
                let activeBytes = UInt64(vmstat.active_count) * pageSize
                let inactiveBytes = UInt64(vmstat.inactive_count) * pageSize
                let speculativeBytes = UInt64(vmstat.speculative_count) * pageSize
                let wireBytes = UInt64(vmstat.wire_count) * pageSize
                let compressedBytes = UInt64(vmstat.compressor_page_count) * pageSize
                let purgeableBytes = UInt64(vmstat.purgeable_count) * pageSize
                let externalBytes = UInt64(vmstat.external_page_count) * pageSize
                
                // Calculate App Memory: active + inactive + speculative - purgeable - external
                let appMemoryBytes = activeBytes + inactiveBytes + speculativeBytes - purgeableBytes - externalBytes
                
                // Total used = App Memory + Wired + Compressed
                let usedBytes = appMemoryBytes + wireBytes + compressedBytes
                
                let usageRatio = Double(usedBytes) / Double(physicalMemory)
                
                if usageRatio > 0.90 {
                    return "Critical"
                } else if usageRatio > 0.80 {
                    return "Warning"
                } else {
                    return "Normal"
                }
            }
        }
        
        return "Normal" // Default fallback
    }
    
    private func getMemoryInfo() -> (used: String, swap: String) {
        var usedMemory = "Unknown"
        var swapMemory = "0 MB"
        
        // Get physical memory size
        var physicalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0) != 0 {
            return (used: usedMemory, swap: swapMemory)
        }
        
        // Get system-wide VM statistics  
        var vmstat = vm_statistics64()
        var vmstatCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let vmResult = withUnsafeMutablePointer(to: &vmstat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmstatCount)
            }
        }
        
        if vmResult == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            
            // Calculate memory components
            let activeBytes = UInt64(vmstat.active_count) * pageSize
            let inactiveBytes = UInt64(vmstat.inactive_count) * pageSize
            let speculativeBytes = UInt64(vmstat.speculative_count) * pageSize
            let wireBytes = UInt64(vmstat.wire_count) * pageSize
            let compressedBytes = UInt64(vmstat.compressor_page_count) * pageSize
            let purgeableBytes = UInt64(vmstat.purgeable_count) * pageSize
            let externalBytes = UInt64(vmstat.external_page_count) * pageSize
            
            // Calculate App Memory using the correct formula:
            // App Memory = active + inactive + speculative - purgeable - external
            let appMemoryBytes = activeBytes + inactiveBytes + speculativeBytes - purgeableBytes - externalBytes
            
            // Total Memory Used = App Memory + Wired + Compressed
            let usedBytes = appMemoryBytes + wireBytes + compressedBytes
            
            // Debug log with all components for comparison with Activity Monitor
            logger.debug("XPC Service: Memory components - App Memory (active+inactive+speculative-purgeable-external): \(Double(appMemoryBytes)/(1024*1024*1024), privacy: .public) GB, Wired: \(Double(wireBytes)/(1024*1024*1024), privacy: .public) GB, Compressed: \(Double(compressedBytes)/(1024*1024*1024), privacy: .public) GB")
            logger.debug("XPC Service: App Memory Used: \(Double(usedBytes)/(1024*1024*1024), privacy: .public) GB")
            logger.debug("XPC Service: Component breakdown - Active: \(Double(activeBytes)/(1024*1024*1024), privacy: .public) GB, Inactive: \(Double(inactiveBytes)/(1024*1024*1024), privacy: .public) GB, Speculative: \(Double(speculativeBytes)/(1024*1024*1024), privacy: .public) GB, Purgeable: \(Double(purgeableBytes)/(1024*1024*1024), privacy: .public) GB, External: \(Double(externalBytes)/(1024*1024*1024), privacy: .public) GB")
            
            let totalGB = Double(physicalMemory) / (1024.0 * 1024.0 * 1024.0)
            let usedGB = Double(usedBytes) / (1024.0 * 1024.0 * 1024.0)
            
            // Show total memory used (App + Wired + Compressed) out of physical memory
            usedMemory = String(format: "%.1f GB of %.1f GB", usedGB, totalGB)
            
            // Get actual swap usage using sysctl
            var swapUsage = xsw_usage()
            var swapSize = MemoryLayout<xsw_usage>.size
            if sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0) == 0 {
                let swapUsedBytes = UInt64(swapUsage.xsu_used)
                if swapUsedBytes > 0 {
                    if swapUsedBytes < 1024 * 1024 * 1024 {
                        swapMemory = String(format: "%.0f MB", Double(swapUsedBytes) / (1024.0 * 1024.0))
                    } else {
                        swapMemory = String(format: "%.1f GB", Double(swapUsedBytes) / (1024.0 * 1024.0 * 1024.0))
                    }
                } else {
                    swapMemory = "0 MB"
                }
            }
        }
        
        return (used: usedMemory, swap: swapMemory)
    }
    
    private func getDetailedMemoryInfo() -> (used: String, swap: String, totalGB: Double, activeGB: Double, wiredGB: Double, compressedGB: Double) {
        var usedMemory = "Unknown"
        var swapMemory = "0 MB"
        var totalGB: Double = 0.0
        var activeGB: Double = 0.0
        var wiredGB: Double = 0.0
        var compressedGB: Double = 0.0
        
        // Get physical memory size
        var physicalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0) != 0 {
            return (used: usedMemory, swap: swapMemory, totalGB: totalGB, 
                    activeGB: activeGB, wiredGB: wiredGB, compressedGB: compressedGB)
        }
        
        // Get system-wide VM statistics  
        var vmstat = vm_statistics64()
        var vmstatCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let vmResult = withUnsafeMutablePointer(to: &vmstat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmstatCount)
            }
        }
        
        if vmResult == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            
            // Calculate memory components
            let activeBytes = UInt64(vmstat.active_count) * pageSize
            let inactiveBytes = UInt64(vmstat.inactive_count) * pageSize
            let speculativeBytes = UInt64(vmstat.speculative_count) * pageSize
            let wireBytes = UInt64(vmstat.wire_count) * pageSize
            let compressedBytes = UInt64(vmstat.compressor_page_count) * pageSize
            let purgeableBytes = UInt64(vmstat.purgeable_count) * pageSize
            let externalBytes = UInt64(vmstat.external_page_count) * pageSize
            
            // Calculate App Memory using the correct formula:
            // App Memory = active + inactive + speculative - purgeable - external
            let appMemoryBytes = activeBytes + inactiveBytes + speculativeBytes - purgeableBytes - externalBytes
            
            // Calculate Active Memory using the formula that matches Activity Monitor exactly
            // Activity Monitor's "Active Memory" = vm_stat.active_count + vm_stat.speculative_count
            let activeMemoryBytes = activeBytes + speculativeBytes
            
            // Convert to GB with 2 decimal precision
            totalGB = Double(physicalMemory) / (1024.0 * 1024.0 * 1024.0)
            let appMemoryGB = Double(appMemoryBytes) / (1024.0 * 1024.0 * 1024.0)
            let activeMemoryGB = Double(activeMemoryBytes) / (1024.0 * 1024.0 * 1024.0)
            wiredGB = Double(wireBytes) / (1024.0 * 1024.0 * 1024.0)
            compressedGB = Double(compressedBytes) / (1024.0 * 1024.0 * 1024.0)
            
            // Use the correct Active Memory calculation that matches Activity Monitor
            activeGB = max(0.0, activeMemoryGB)  // Ensure non-negative
            
            // Validate all values to prevent negative numbers under high pressure
            let validatedActiveGB = max(0.0, activeGB)
            let validatedWiredGB = max(0.0, wiredGB)
            let validatedCompressedGB = max(0.0, compressedGB)
            
            // Format the used memory with breakdown showing App Memory and system components
            let compressedFormatted: String
            if validatedCompressedGB < 1.0 {
                compressedFormatted = String(format: "%.0f MB", validatedCompressedGB * 1024)
            } else {
                compressedFormatted = String(format: "%.2f GB", validatedCompressedGB)
            }
            
            // Calculate total memory used: App Memory + Wired + Compressed
            let totalUsedMemoryGB = appMemoryGB + validatedWiredGB + validatedCompressedGB
            
            // Display format: "Total Used (App + Wired + Compressed)"
            usedMemory = String(format: "%.2f GB (App:%.2f + W:%.2f + C:%@)", 
                               totalUsedMemoryGB, appMemoryGB, validatedWiredGB, compressedFormatted)
            
            // Enhanced debug logging for memory statistics
            logger.debug("XPC Service: Memory breakdown - App Memory: \(appMemoryGB, privacy: .public) GB, Active: \(validatedActiveGB, privacy: .public) GB, Wired: \(validatedWiredGB, privacy: .public) GB, Compressed: \(validatedCompressedGB, privacy: .public) GB")
            
            // Validate memory relationships
            if validatedActiveGB > appMemoryGB {
                logger.warning("XPC Service: Active Memory (\(validatedActiveGB, privacy: .public) GB) is greater than App Memory (\(appMemoryGB, privacy: .public) GB) - unusual but possible under high pressure")
            }
            
            if activeMemoryGB < 0 {
                logger.warning("XPC Service: Detected negative active memory calculation - raw: \(activeMemoryGB, privacy: .public) GB, corrected to: \(validatedActiveGB, privacy: .public) GB")
            }
            
            if vmstat.internal_page_count > UInt32.max / 2 || vmstat.external_page_count > UInt32.max / 2 {
                logger.warning("XPC Service: High memory pressure detected - internal: \(vmstat.internal_page_count), external: \(vmstat.external_page_count)")
            }
            
            // Get actual swap usage using sysctl
            var swapUsage = xsw_usage()
            var swapSize = MemoryLayout<xsw_usage>.size
            if sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0) == 0 {
                let swapUsedBytes = UInt64(swapUsage.xsu_used)
                if swapUsedBytes > 0 {
                    if swapUsedBytes < 1024 * 1024 * 1024 {
                        swapMemory = String(format: "%.2f MB", Double(swapUsedBytes) / (1024.0 * 1024.0))
                    } else {
                        swapMemory = String(format: "%.2f GB", Double(swapUsedBytes) / (1024.0 * 1024.0 * 1024.0))
                    }
                } else {
                    swapMemory = "0.00 MB"
                }
            }
        }
        
        return (used: usedMemory, swap: swapMemory, totalGB: totalGB, 
                activeGB: activeGB, wiredGB: wiredGB, compressedGB: compressedGB)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

class MemBarHelperServiceDelegate: NSObject, NSXPCListenerDelegate {
    
    private let logger = Logger(subsystem: "First.MemBarHelper", category: "XPCDelegate")
    
    /// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        logger.info("XPC Service: New connection request received")
        
        // Configure the connection.
        // First, set the interface that the exported object implements.
        newConnection.exportedInterface = NSXPCInterface(with: MemBarHelperProtocol.self)
        
        // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
        let exportedObject = MemBarHelperService()
        newConnection.exportedObject = exportedObject
        
        // Add error handlers
        newConnection.invalidationHandler = {
            self.logger.info("XPC Service: Connection invalidated")
        }
        
        newConnection.interruptionHandler = {
            self.logger.info("XPC Service: Connection interrupted")
        }
        
        // Resuming the connection allows the system to deliver more incoming messages.
        newConnection.resume()
        
        logger.info("XPC Service: Connection accepted and resumed")
        
        // Returning true from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call invalidate() on the connection and return false.
        return true
    }
}

// MARK: - Main Entry Point

let logger = Logger(subsystem: "First.MemBarHelper", category: "Main")
logger.info("XPC Service: Starting MemBarHelper service")

let delegate = MemBarHelperServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate

logger.info("XPC Service: Listener configured, resuming...")

// Resuming the serviceListener starts this service. This method does not return.
listener.resume()

// Keep the service running
RunLoop.main.run()
