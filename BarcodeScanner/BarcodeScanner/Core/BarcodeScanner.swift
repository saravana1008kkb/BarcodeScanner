//
//  BarcodeScanner.swift
//  BarcodeScanner
//
//  Created by Saravanakumar Balasubramanian on 10/11/24.
//
import AVFoundation
import Vision
import UIKit

@objc public class BarcodeScaner: NSObject {
    
    @objc public static let shared = BarcodeScaner()
    
    private override init() {
        super.init()
    }
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var barcodeRequest: VNDetectBarcodesRequest?
    private let barcodeScannerQueue = DispatchQueue(label: "Barcode Scanner Queue")
    private var onSuccess: ((String) -> Void)?
    private var onFailure: ((Error) -> Void)?
    private var delegateWrapper: AVCaptureDelegateWrapper?
    private let supportFormats: [VNBarcodeSymbology] = [.qr, .ean13, .ean8, .code128, .upce, .code39]
    
    @objc public func checkPermission(mediaType: AVMediaType, completion: @escaping ((Bool, String?) -> Void)) {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: mediaType)
        
        switch cameraAuthorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                completion(granted, granted ? nil : "Camera access denied.")
            }
        case .authorized:
            completion(true, nil)
            
        case .restricted, .denied:
            completion(false, "Camera access denied.")
            
        @unknown default:
            completion(false, "Unknown camera authorization status.")
        }
    }
    
    @objc public func startSession(cameraView: UIView, onSuccess: ((String) -> Void)?, onFailure: ((Error) -> Void)?) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
        setupBarcodeDetection()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.configureCameraSession(cameraView: cameraView)
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
    }
    
    @objc public func stopSession() {
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
    }
    
    private func configureCameraSession(cameraView: UIView) {
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let validCaptureSession = captureSession else {
            return
        }
        let videoInput: AVCaptureDeviceInput
        let videoOutput: AVCaptureVideoDataOutput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Caught exception as \(error.localizedDescription)")
            return
        }
        
        if validCaptureSession.canAddInput(videoInput) {
            validCaptureSession.addInput(videoInput)
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        delegateWrapper = AVCaptureDelegateWrapper(scanner: self, barcodeRequest: barcodeRequest)
        videoOutput.setSampleBufferDelegate(delegateWrapper, queue: barcodeScannerQueue)
        
        if validCaptureSession.canAddOutput(videoOutput) {
            validCaptureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = cameraView.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        DispatchQueue.main.async {
            cameraView.layer.addSublayer(self.previewLayer!)
        }
    }
    
    private func setupBarcodeDetection() {
        barcodeRequest = VNDetectBarcodesRequest { [weak self] request, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let validErr = error {
                    self.onFailure?(validErr)
                    return
                }
                
                if let results = request.results as? [VNBarcodeObservation] {
                    for barcode in results {
                        if let validPayload = barcode.payloadStringValue {
                            self.onSuccess?(validPayload)
                            return
                        }
                    }
                }
            }
        }
        barcodeRequest?.symbologies = supportFormats
    }
}

private class AVCaptureDelegateWrapper: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private weak var scanner: BarcodeScaner?
    private var barcodeRequest: VNDetectBarcodesRequest?
    
    init(scanner: BarcodeScaner, barcodeRequest: VNDetectBarcodesRequest?) {
        self.scanner = scanner
        self.barcodeRequest = barcodeRequest
        super.init()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let validBarcodeRequest = barcodeRequest else { return }
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try requestHandler.perform([validBarcodeRequest])
        }
        catch {
            print("Caught err in camera outpur delegate as \(error.localizedDescription)")
        }
    }
}
