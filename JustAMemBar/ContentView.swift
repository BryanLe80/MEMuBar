//
//  ContentView.swift
//  JustAMemBar
//
//  Created by Bryan Le on 5/24/25.
//

import SwiftUI

struct ContentView: View {
    @State private var memoryData: MemoryData?
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    private let xpcClient = MemBarXPCClient()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MemBar XPC Test")
                .font(.title)
                .padding()
            
            if isLoading {
                ProgressView("Getting memory statistics...")
            } else {
                Button("Test XPC Communication") {
                    testXPCCommunication()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            if let memoryData = memoryData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Statistics:")
                        .font(.headline)
                    
                    Text("Pressure: \(memoryData.memoryPressure)")
                    Text("Used: \(memoryData.memoryUsed)")
                    Text("Swap: \(memoryData.swapUsed)")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func testXPCCommunication() {
        isLoading = true
        errorMessage = nil
        memoryData = nil
        
        xpcClient.getMemoryStatistics { data, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                } else if let data = data {
                    memoryData = data
                } else {
                    errorMessage = "Unknown error occurred"
                }
            }
        }
    }
}

#Preview {
    ContentView()
} 
