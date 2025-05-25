//
//  MemBarHelperProtocol.swift
//  JustAMemBar
//
//  Created by Bryan Le on 5/24/25.
//

import Foundation

// MARK: - XPC Protocol Definition

@objc public protocol MemBarHelperProtocol: NSObjectProtocol {
    func getMemoryStatistics(reply: @escaping (String, String, String) -> Void)
    func getDetailedMemoryStatistics(reply: @escaping (String, String, String, Double, Double, Double, Double) -> Void)
}

// MARK: - Data Transfer Model

@objc public class MemoryData: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool = true
    
    @objc public var memoryPressure: String
    @objc public var memoryUsed: String
    @objc public var swapUsed: String

    public init(memoryPressure: String, memoryUsed: String, swapUsed: String) {
        self.memoryPressure = memoryPressure
        self.memoryUsed = memoryUsed
        self.swapUsed = swapUsed
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        guard let memoryPressure = coder.decodeObject(of: NSString.self, forKey: "memoryPressure") as String?,
              let memoryUsed = coder.decodeObject(of: NSString.self, forKey: "memoryUsed") as String?,
              let swapUsed = coder.decodeObject(of: NSString.self, forKey: "swapUsed") as String? else {
            return nil
        }
        
        self.memoryPressure = memoryPressure
        self.memoryUsed = memoryUsed
        self.swapUsed = swapUsed
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(memoryPressure, forKey: "memoryPressure")
        coder.encode(memoryUsed, forKey: "memoryUsed")
        coder.encode(swapUsed, forKey: "swapUsed")
    }
}

@objc public class DetailedMemoryData: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool = true
    
    @objc public var memoryPressure: String
    @objc public var memoryUsed: String
    @objc public var swapUsed: String
    @objc public var totalGB: Double
    @objc public var activeGB: Double
    @objc public var wiredGB: Double
    @objc public var compressedGB: Double

    public init(memoryPressure: String, memoryUsed: String, swapUsed: String, 
                totalGB: Double, activeGB: Double, wiredGB: Double, compressedGB: Double) {
        self.memoryPressure = memoryPressure
        self.memoryUsed = memoryUsed
        self.swapUsed = swapUsed
        self.totalGB = totalGB
        self.activeGB = activeGB
        self.wiredGB = wiredGB
        self.compressedGB = compressedGB
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        guard let memoryPressure = coder.decodeObject(of: NSString.self, forKey: "memoryPressure") as String?,
              let memoryUsed = coder.decodeObject(of: NSString.self, forKey: "memoryUsed") as String?,
              let swapUsed = coder.decodeObject(of: NSString.self, forKey: "swapUsed") as String? else {
            return nil
        }
        
        self.memoryPressure = memoryPressure
        self.memoryUsed = memoryUsed
        self.swapUsed = swapUsed
        self.totalGB = coder.decodeDouble(forKey: "totalGB")
        self.activeGB = coder.decodeDouble(forKey: "activeGB")
        self.wiredGB = coder.decodeDouble(forKey: "wiredGB")
        self.compressedGB = coder.decodeDouble(forKey: "compressedGB")
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(memoryPressure, forKey: "memoryPressure")
        coder.encode(memoryUsed, forKey: "memoryUsed")
        coder.encode(swapUsed, forKey: "swapUsed")
        coder.encode(totalGB, forKey: "totalGB")
        coder.encode(activeGB, forKey: "activeGB")
        coder.encode(wiredGB, forKey: "wiredGB")
        coder.encode(compressedGB, forKey: "compressedGB")
    }
} 
