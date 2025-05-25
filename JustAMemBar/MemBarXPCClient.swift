//
//  MemBarXPCClient.swift
//  JustAMemBar
//
//  Created by Bryan Le on 5/24/25.
//

import Foundation
import os.log

class MemBarXPCClient {
    private var connection: NSXPCConnection?
    private let logger = Logger(subsystem: "First.JustAMemBar", category: "XPCClient")
    
    init() {
        setupConnection()
    }
    
    private func setupConnection() {
        logger.info("XPC Client: Setting up connection to MemBarHelper service")
        
        // XPC service bundle identifier
        connection = NSXPCConnection(serviceName: "First.MemBarHelper")
        
        // Set up the interface
        let interface = NSXPCInterface(with: MemBarHelperProtocol.self)
        connection?.remoteObjectInterface = interface
        
        connection?.invalidationHandler = {
            self.logger.error("XPC Client: Connection invalidated")
            self.connection = nil
        }
        
        connection?.interruptionHandler = {
            self.logger.error("XPC Client: Connection interrupted")
            // Attempt to reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.setupConnection()
            }
        }
        
        logger.info("XPC Client: Resuming connection")
        connection?.resume()
    }
    
    func getMemoryStatistics(completion: @escaping (MemoryData?, Error?) -> Void) {
        logger.info("XPC Client: getMemoryStatistics called")
        
        guard let connection = connection else {
            logger.error("XPC Client: No XPC connection available")
            completion(nil, NSError(domain: "XPCError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No XPC connection"]))
            return
        }
        
        logger.info("XPC Client: Getting remote object proxy")
        
        let service = connection.remoteObjectProxyWithErrorHandler { error in
            self.logger.error("XPC Client: Remote object proxy error: \(error.localizedDescription)")
            completion(nil, error)
        } as? MemBarHelperProtocol
        
        guard let service = service else {
            logger.error("XPC Client: Failed to get service proxy")
            completion(nil, NSError(domain: "XPCError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get service proxy"]))
            return
        }
        
        logger.info("XPC Client: Calling getDetailedMemoryStatistics on service")
        
        service.getDetailedMemoryStatistics { memoryPressure, memoryUsed, swapUsed, totalGB, activeGB, wiredGB, compressedGB in
            self.logger.info("XPC Client: Received detailed response - Pressure: \(memoryPressure), Used: \(memoryUsed), Swap: \(swapUsed)")
            self.logger.info("XPC Client: Memory breakdown - Total: \(totalGB), Active: \(activeGB), Wired: \(wiredGB), Compressed: \(compressedGB)")
            
            let memoryData = MemoryData(
                memoryPressure: memoryPressure,
                memoryUsed: memoryUsed,
                swapUsed: swapUsed
            )
            completion(memoryData, nil)
        }
    }
    
    deinit {
        logger.info("XPC Client: Deinitializing, invalidating connection")
        connection?.invalidate()
    }
} 
