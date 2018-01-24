//
//  ViewController.swift
//  BarCodeScanner
//
//  Created by David G. Young on 1/24/18.
//  Copyright © 2018 David G. Young. All rights reserved.
//

import UIKit

import AVFoundation
import UIKit


class BarCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var barCodeFrameView: UIView? // for Extra credit section 3
    var initialized = false

    let barCodeTypes = [AVMetadataObject.ObjectType.upce,
                        AVMetadataObject.ObjectType.code39,
                        AVMetadataObject.ObjectType.code39Mod43,
                        AVMetadataObject.ObjectType.code93,
                        AVMetadataObject.ObjectType.code128,
                        AVMetadataObject.ObjectType.ean8,
                        AVMetadataObject.ObjectType.ean13,
                        AVMetadataObject.ObjectType.aztec,
                        AVMetadataObject.ObjectType.pdf417,
                        AVMetadataObject.ObjectType.itf14,
                        AVMetadataObject.ObjectType.dataMatrix,
                        AVMetadataObject.ObjectType.interleaved2of5,
                        AVMetadataObject.ObjectType.qr]

    var crosshairView: CrosshairView? = nil // For Extra credit section 2

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Bar Code Scanner"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if crosshairView == nil {
            crosshairView = CrosshairView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
            crosshairView?.backgroundColor = UIColor.clear
            self.view.addSubview(crosshairView!)
        }
        setupCapture()
        // set observer for UIApplicationWillEnterForeground, so we know when to start the capture session again
        // if the user switches to another app (e.g. Safari) then comes back
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: .UIApplicationWillEnterForeground, object: nil)
    }
    
    // This is called when we return from Safari or another app to the scanner view
    @objc func willEnterForeground() {
        setupCapture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // this view is no longer topmost in the app, so we don't need a callback if we return to the app.
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillEnterForeground, object: nil)
    }
    
    func setupCapture() {
        // Extra credit section 3
        if let barCodeFrameView = barCodeFrameView {
            barCodeFrameView.removeFromSuperview()
            self.barCodeFrameView = nil
        }
        var success = false
        var accessDenied = false
        var accessRequested = false
        if let barCodeFrameView = barCodeFrameView {
            barCodeFrameView.removeFromSuperview()
            self.barCodeFrameView = nil
        }

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus == .notDetermined {
            // permission dialog not yet presented, request authorization
            accessRequested = true
            AVCaptureDevice.requestAccess(for: .video,
                                          completionHandler: { (granted:Bool) -> Void in
                                          self.setupCapture();
            })
            return
        }
        if authorizationStatus == .restricted || authorizationStatus == .denied {
            accessDenied = true
        }
        
        if initialized {
            success = true
        }
        else {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInDualCamera], mediaType: AVMediaType.video, position: .unspecified)
            
            if let captureDevice = deviceDiscoverySession.devices.first {
                do {
                    let videoInput = try AVCaptureDeviceInput(device: captureDevice)
                    captureSession.addInput(videoInput)
                    success = true
                } catch {
                    NSLog("Cannot construct capture device input")
                }
            }
            else {
                NSLog("Cannot get capture device")
            }
            
            if success {
                let captureMetadataOutput = AVCaptureMetadataOutput()
                captureSession.addOutput(captureMetadataOutput)
                let newSerialQueue = DispatchQueue(label: "barCodeScannerQueue") // in iOS 11 you can use main queue
                captureMetadataOutput.setMetadataObjectsDelegate(self, queue: newSerialQueue)
                captureMetadataOutput.metadataObjectTypes = barCodeTypes
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                videoPreviewLayer?.videoGravity = .resizeAspectFill
                videoPreviewLayer?.frame = view.layer.bounds
                view.layer.addSublayer(videoPreviewLayer!)
                initialized = true
            }
        }
        if success {
            captureSession.startRunning()
            view.bringSubview(toFront: crosshairView!)
        }

        // ----------------------
        // Extra credit section 1
        // If we cannot establish a camera capture session for some reason, show a dialog to the user explaining why
        // ----------------------
        
        if !success {
            // Only show a dialog if we have not just asked the user for permission to use the camera.  Asking permission
            // sends its own dialog to th user
            if !accessRequested {
                // Generic message if we cannot figure out why we cannot establish a camera session
                var message = "Cannot access camera to scan bar codes"
                #if (arch(i386) || arch(x86_64)) && (!os(macOS))
                    message = "You are running on the simulator, which does not hae a camera device.  Try this on a real iOS device."
                #endif
                if accessDenied {
                    message = "You have denied this app permission to access to the camera.  Please go to settings and enable camera access permission to be able to scan bar codes"
                }
                let alertPrompt = UIAlertController(title: "Cannot access camera", message: message, preferredStyle: .alert)
                let confirmAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) -> Void in
                    self.navigationController?.popViewController(animated: true)
                })
                alertPrompt.addAction(confirmAction)
                self.present(alertPrompt, animated: true, completion: {
                })
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    // Swift 3.x callback
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        processBarCodeData(metadataObjects: metadataObjects as! [AVMetadataObject])
    }
    
    // Swift 4 callback
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        processBarCodeData(metadataObjects: metadataObjects)
    }
    
    func processBarCodeData(metadataObjects: [AVMetadataObject]) {
        if metadataObjects.count == 0 {
            barCodeFrameView?.frame = CGRect.zero // Extra credit section 3
            return
        }
        
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
            if barCodeTypes.contains(metadataObject.type) {
                // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
                let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObject)
                // Initialize Frame to highlight the Bar Code
                DispatchQueue.main.async {
                    // Extra credit section 3
                    if self.barCodeFrameView == nil {
                        self.barCodeFrameView = UIView()
                        if let barCodeFrameView = self.barCodeFrameView {
                            barCodeFrameView.layer.borderColor = UIColor.yellow.cgColor
                            barCodeFrameView.layer.borderWidth = 2
                            self.view.addSubview(barCodeFrameView)
                            self.view.bringSubview(toFront: barCodeFrameView)
                        }
                    }
                    self.barCodeFrameView?.frame = barCodeObject!.bounds
                }
                
                if metadataObject.stringValue != nil {
                    captureSession.stopRunning()
                    displayBarCodeResult(code: metadataObject.stringValue!)
                    // because there might be more bar codes detected, we return from the loop early
                    // here so we do not process more than one
                    return
                }
            }
        }
    }
    
    func displayBarCodeResult(code: String) {
        let alertPrompt = UIAlertController(title: "Bar code detected", message: code, preferredStyle: .alert)
        if let url = URL(string: code) {
            let confirmAction = UIAlertAction(title: "Launch URL", style: UIAlertActionStyle.default, handler: { (action) -> Void in
                UIApplication.shared.open(url, options: [:], completionHandler: { (result) in
                    if result {
                        NSLog("opened url")
                    }
                    else {
                        let alertPrompt = UIAlertController(title: "Cannot open url", message: nil, preferredStyle: .alert)
                        let confirmAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) -> Void in
                        })
                        alertPrompt.addAction(confirmAction)
                        self.present(alertPrompt, animated: true, completion: {
                            self.setupCapture()
                        })
                    }
                })
                
            })
            alertPrompt.addAction(confirmAction)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) -> Void in
            self.setupCapture()
        })
        alertPrompt.addAction(cancelAction)
        present(alertPrompt, animated: true, completion: nil)
    }
    
    // ----------------------
    // Extra credit section 2
    // Draw crosshairs over camera view
    // ----------------------
    class CrosshairView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public override func draw(_ rect: CGRect) {
            let fWidth = self.frame.size.width
            let fHeight = self.frame.size.height
            let squareWidth = fWidth/2
            let topLeft = CGPoint(x: fWidth/2-squareWidth/2, y: fHeight/2-squareWidth/2)
            let topRight = CGPoint(x: fWidth/2+squareWidth/2, y: fHeight/2-squareWidth/2)
            let bottomLeft = CGPoint(x: fWidth/2-squareWidth/2, y: fHeight/2+squareWidth/2)
            let bottomRight = CGPoint(x: fWidth/2+squareWidth/2, y: fHeight/2+squareWidth/2)
            let cornerWidth = squareWidth/4
            
            if let context = UIGraphicsGetCurrentContext() {
                context.setLineWidth(2.0)
                context.setStrokeColor(UIColor.green.cgColor)
                
                // top left corner
                context.move(to: topLeft)
                context.addLine(to: CGPoint(x: fWidth/2-squareWidth/2+cornerWidth, y: fHeight/2-squareWidth/2))
                context.strokePath()
                
                context.move(to: topLeft)
                context.addLine(to: CGPoint(x: fWidth/2-squareWidth/2, y: fHeight/2-squareWidth/2+cornerWidth))
                context.strokePath()
                
                // top right corner
                context.move(to: topRight)
                context.addLine(to: CGPoint(x: fWidth/2+squareWidth/2, y: fHeight/2-squareWidth/2+cornerWidth))
                context.strokePath()
                
                context.move(to: topRight)
                context.addLine(to: CGPoint(x: fWidth/2+squareWidth/2-cornerWidth, y: fHeight/2-squareWidth/2))
                context.strokePath()
                
                // bottom right corner
                context.move(to: bottomRight)
                context.addLine(to: CGPoint(x: fWidth/2+squareWidth/2-cornerWidth, y: fHeight/2+squareWidth/2))
                context.strokePath()
                
                context.move(to: bottomRight)
                context.addLine(to: CGPoint(x: fWidth/2+squareWidth/2, y: fHeight/2+squareWidth/2-cornerWidth))
                context.strokePath()
                
                // bottom left corner
                context.move(to: bottomLeft)
                context.addLine(to: CGPoint(x: fWidth/2-squareWidth/2+cornerWidth, y: fHeight/2+squareWidth/2))
                context.strokePath()
                
                context.move(to: bottomLeft)
                context.addLine(to: CGPoint(x: fWidth/2-squareWidth/2, y: fHeight/2+squareWidth/2-cornerWidth))
                context.strokePath()
                
                
            }
        }
    }
    
    
}
