//
//  ContentView.swift
//  EasyBarcodeScanner
//
//  Created by Saravanakumar Balasubramanian on 10/11/24.
//

import SwiftUI
import UIKit
import BarcodeScanner

struct ContentView: View {
    @State private var scannedCode: String = ""
    @State private var scannedErr: String = ""
    @State private var isScanning: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            if isScanning {
                CameraPreviewView(scannedCode: $scannedCode, scanErrMessage: $scannedErr, isScanning: $isScanning)
                    .frame(width: 300, height: 300)
            } else {
                Text("Scan Barcode here.")
            }
            if !scannedCode.isEmpty {
                Text("Found code \(scannedCode)")
            } else if !scannedErr.isEmpty {
                Text("Got error \(scannedErr)")
            }
            
            Button(isScanning ? "Stop Scanning" : "Start Scanning") {
                isScanning.toggle()
            }
        }
        .onChange(of: scannedCode, { _, _ in
            if isScanning { isScanning.toggle() }
        })
        .onChange(of: scannedErr, { _, _ in
            if isScanning { isScanning.toggle() }
        })
        .padding()
    }
}

struct CameraPreviewView: UIViewRepresentable {
    @Binding var scannedCode: String
    @Binding var scanErrMessage: String
    @Binding var isScanning: Bool
    
    func makeUIView(context: Context) -> UIView {
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        contentView.backgroundColor = .black
        return contentView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if isScanning {
            configureScannerAndStartIfValid(uiView)
        } else {
            stopSession()
        }
    }
    
    func configureScannerAndStartIfValid(_ uiView: UIView) {
        BarcodeScaner.shared.checkPermission(mediaType: .video) { status, errMsg in
            DispatchQueue.main.async {
                if status {
                    BarcodeScaner.shared.startSession(cameraView: uiView, onSuccess: { scannedCode in
                        self.scannedCode = scannedCode
                    }, onFailure: { error in
                        self.scanErrMessage = error.localizedDescription
                    })
                } else if let validErr = errMsg {
                    self.scanErrMessage = validErr
                }
            }
        }
    }
    
    func stopSession() {
        BarcodeScaner.shared.stopSession()
    }
}

#Preview {
    ContentView()
}
