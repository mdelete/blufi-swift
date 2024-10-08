//
//  QRScannerViewController.swift
//  BluFiExample
//
//  Created by Marc Delling on 18.04.22.
//  Copyright © 2022 Marc Delling. All rights reserved.
//

import UIKit
import CoreGraphics
import AVFoundation

public protocol QRScannerCodeDelegate: AnyObject {
    func qrScanner(_ controller: UIViewController, scanDidComplete result: String)
    func qrScannerDidFail(_ controller: UIViewController,  error: String)
    func qrScannerDidCancel(_ controller: UIViewController)
}

open class SquareView: UIView {
    
    var sizeMultiplier : CGFloat = 0.1 {
        didSet { self.draw(self.bounds) }
    }
    
    var lineWidth : CGFloat = 2 {
        didSet { self.draw(self.bounds) }
    }
    
    var lineColor : UIColor = UIColor.green {
        didSet { self.draw(self.bounds) }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = UIColor.clear
    }
    
    func drawCorners() {
        let rectCornerContext = UIGraphicsGetCurrentContext()
        
        rectCornerContext?.setLineWidth(lineWidth)
        rectCornerContext?.setStrokeColor(lineColor.cgColor)
        
        //top left corner
        rectCornerContext?.beginPath()
        rectCornerContext?.move(to: CGPoint(x: 0, y: 0))
        rectCornerContext?.addLine(to: CGPoint(x: self.bounds.size.width*sizeMultiplier, y: 0))
        rectCornerContext?.strokePath()
        
        //top right corner
        rectCornerContext?.beginPath()
        rectCornerContext?.move(to: CGPoint(x: self.bounds.size.width - self.bounds.size.width*sizeMultiplier, y: 0))
        rectCornerContext?.addLine(to: CGPoint(x: self.bounds.size.width, y: 0))
        rectCornerContext?.addLine(to: CGPoint(x: self.bounds.size.width, y: self.bounds.size.height*sizeMultiplier))
        rectCornerContext?.strokePath()
        
        //bottom right corner
        rectCornerContext?.beginPath()
        rectCornerContext?.move(to: CGPoint(x: self.bounds.size.width, y: self.bounds.size.height - self.bounds.size.height*sizeMultiplier))
        rectCornerContext?.addLine(to: CGPoint(x: self.bounds.size.width, y: self.bounds.size.height))
        rectCornerContext?.addLine(to: CGPoint(x: self.bounds.size.width - self.bounds.size.width*sizeMultiplier, y: self.bounds.size.height))
        rectCornerContext?.strokePath()
        
        //bottom left corner
        rectCornerContext?.beginPath()
        rectCornerContext?.move(to: CGPoint(x: self.bounds.size.width*sizeMultiplier, y: self.bounds.size.height))
        rectCornerContext?.addLine(to: CGPoint(x: 0, y: self.bounds.size.height))
        rectCornerContext?.addLine(to: CGPoint(x: 0, y: self.bounds.size.height - self.bounds.size.height*sizeMultiplier))
        rectCornerContext?.strokePath()
        
        //second part of top left corner
        rectCornerContext?.beginPath()
        rectCornerContext?.move(to: CGPoint(x: 0, y: self.bounds.size.height*sizeMultiplier))
        rectCornerContext?.addLine(to: CGPoint(x: 0, y: 0))
        rectCornerContext?.strokePath()
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        self.drawCorners()
    }
}

public class QRCodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationBarDelegate {
    
    var squareView: SquareView? = nil
    public weak var delegate: QRScannerCodeDelegate?
    private var flashButton: UIButton? = nil
    
    public var cameraImage: UIImage? = nil
    public var cancelImage: UIImage? = nil
    public var flashOnImage: UIImage? = nil
    public var flashOffImage: UIImage? = nil

    private let bottomSpace: CGFloat = 80.0
    private let spaceFactor: CGFloat = 16.0
    private let devicePosition: AVCaptureDevice.Position = .back
    private var delCnt: Int = 0
    private let delayCount: Int = 15
    
    lazy var defaultDevice: AVCaptureDevice? = {
        if let device = AVCaptureDevice.default(for: .video) {
            return device
        }
        return nil
    }()
    
    lazy var frontDevice: AVCaptureDevice? = {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            return device
        }
        return nil
    }()
    
    lazy var defaultCaptureInput: AVCaptureInput? = {
        if let captureDevice = defaultDevice {
            do {
                return try AVCaptureDeviceInput(device: captureDevice)
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }()
    
    lazy var frontCaptureInput: AVCaptureInput?  = {
        if let captureDevice = frontDevice {
            do {
                return try AVCaptureDeviceInput(device: captureDevice)
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }()
    
    lazy var dataOutput = AVCaptureMetadataOutput()
    lazy var captureSession = AVCaptureSession()
    
    lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        layer.cornerRadius = 10.0
        return layer
    }()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience public init(cameraImage: UIImage?, cancelImage: UIImage?, flashOnImage: UIImage?, flashOffImage: UIImage?) {
        self.init()
        self.cameraImage = cameraImage
        self.cancelImage = cancelImage
        self.flashOnImage = flashOnImage
        self.flashOffImage = flashOffImage
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        delCnt = 0
        prepareQRScannerView(self.view)
        startScanningQRCode()
    }
    
    func prepareQRScannerView(_ view: UIView) {
        setupCaptureSession(devicePosition)
        addVideoPreviewLayer(view)
        createCornerFrame()
        addButtons(view)
    }
    
    func createCornerFrame() {
        let width: CGFloat = 200.0
        let height: CGFloat = 200.0
        let rect = CGRect.init(origin: CGPoint.init(x: self.view.frame.midX - width/2, y: self.view.frame.midY - (width+bottomSpace)/2), size: CGSize.init(width: width, height: height))
        self.squareView = SquareView(frame: rect)
        if let squareView = squareView {
            self.view.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            squareView.autoresizingMask = UIView.AutoresizingMask(rawValue: UInt(0.0))
            self.view.addSubview(squareView)
            addMaskLayerToVideoPreviewLayerAndAddText(rect: rect)
        }
    }
    
    func addMaskLayerToVideoPreviewLayerAndAddText(rect: CGRect) {

        let maskLayer = CAShapeLayer()
        maskLayer.frame = view.bounds
        maskLayer.fillColor = UIColor(white: 0.0, alpha: 0.5).cgColor
        let path = UIBezierPath(rect: rect)
        path.append(UIBezierPath(rect: view.bounds))
        maskLayer.path = path.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        view.layer.insertSublayer(maskLayer, above: videoPreviewLayer)
        
        let noteText = CATextLayer()
        noteText.fontSize = 18.0
        noteText.string = "Align QR code within frame to scan"
        noteText.alignmentMode = CATextLayerAlignmentMode.center
        noteText.contentsScale = UIScreen.main.scale
        noteText.frame = CGRect(x: spaceFactor, y: rect.origin.y + rect.size.height + 30, width: view.frame.size.width - (2.0 * spaceFactor), height: 22)
        noteText.foregroundColor = UIColor.white.cgColor
        view.layer.insertSublayer(noteText, above: maskLayer)
    }
    
    private func addButtons(_ view: UIView) {
        
        let height: CGFloat = 44.0
        let width: CGFloat = 44.0
        /*
        let btnWidthWhenCancelImageNil: CGFloat = 60.0
        
        let cancelButton = UIButton()
        if let cancelImg = cancelImage {
            cancelButton.frame = CGRect(
                x: view.frame.width/2 - width/2,
                y: view.frame.height - 60,
                width: width,
                height: height)
            cancelButton.setImage(cancelImg, for: .normal)
        } else {
            cancelButton.frame = CGRect(
                x: view.frame.width/2 - btnWidthWhenCancelImageNil/2,
                y: view.frame.height - 60,
                width: btnWidthWhenCancelImageNil,
                height: height)
            cancelButton.setTitle("Cancel", for: .normal)
        }
        cancelButton.contentMode = .scaleAspectFit
        cancelButton.addTarget(self, action: #selector(dismissVC), for:.touchUpInside)
        view.addSubview(cancelButton)
        */
        
        if let flashOffImg = flashOffImage {
            let flashButtonFrame = CGRect(x: 16, y: self.view.bounds.size.height - (bottomSpace + height + 10), width: width, height: height)
            flashButton = createButtons(flashButtonFrame, height: height)
            flashButton!.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
            flashButton!.setImage(flashOffImg, for: .normal)
            view.addSubview(flashButton!)
        }
        
        if let cameraImg = cameraImage {
            let frame = CGRect(x: self.view.bounds.width - (width + 16), y: self.view.bounds.size.height - (bottomSpace + height + 10), width: width, height: height)
            let cameraSwitchButton = createButtons(frame, height: height)
            cameraSwitchButton.setImage(cameraImg, for: .normal)
            cameraSwitchButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
            view.addSubview(cameraSwitchButton)
        }
    }
    
    func createButtons(_ frame: CGRect, height: CGFloat) -> UIButton {
        let button = UIButton()
        button.frame = frame
        button.tintColor = UIColor.white
        button.layer.cornerRadius = height/2
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.contentMode = .scaleAspectFit
        return button
    }
    
    @objc func toggleTorch() {

        if let currentInput = getCurrentInput() {
            if currentInput.device.position == .front { return }
        }
        
        guard  let defaultDevice = defaultDevice else {return}
        if defaultDevice.isTorchAvailable {
            do {
                try defaultDevice.lockForConfiguration()
                defaultDevice.torchMode = defaultDevice.torchMode == .on ? .off : .on
                if defaultDevice.torchMode == .on {
                    if let flashOnImage = flashOnImage {
                        flashButton!.setImage(flashOnImage, for: .normal)
                    }
                } else {
                    if let flashOffImage = flashOffImage {
                        flashButton!.setImage(flashOffImage, for: .normal)
                    }
                }
                
                defaultDevice.unlockForConfiguration()
            } catch let error as NSError {
                print(error)
            }
        }
    }
    
    @objc func switchCamera() {
        if let frontDeviceInput = frontCaptureInput {
            captureSession.beginConfiguration()
            if let currentInput = getCurrentInput() {
                captureSession.removeInput(currentInput)
                let newDeviceInput = (currentInput.device.position == .front) ? defaultCaptureInput : frontDeviceInput
                captureSession.addInput(newDeviceInput!)
            }
            captureSession.commitConfiguration()
        }
    }
    
    private func getCurrentInput() -> AVCaptureDeviceInput? {
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            return currentInput
        }
        return nil
    }
    
    @objc func dismissVC() {
        self.dismiss(animated: true, completion: nil)
        delegate?.qrScannerDidCancel(self)
    }
    
    // MARK: - Setup and start capturing session
    
    open func startScanningQRCode() {
        if captureSession.isRunning { return }
        //captureSession.startRunning()
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func setupCaptureSession(_ devicePostion: AVCaptureDevice.Position) {
        if captureSession.isRunning { return }
        
        switch devicePosition {
        case .front:
            if let frontDeviceInput = frontCaptureInput {
                if !captureSession.canAddInput(frontDeviceInput) {
                    delegate?.qrScannerDidFail(self, error: "failed to add input")
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                captureSession.addInput(frontDeviceInput)
            }
            break
        case .back, .unspecified :
            if let defaultDeviceInput = defaultCaptureInput {
                if !captureSession.canAddInput(defaultDeviceInput) {
                    delegate?.qrScannerDidFail(self, error: "failed to add input")
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                captureSession.addInput(defaultDeviceInput)
            }
            break
        default: ()
        }
        
        if !captureSession.canAddOutput(dataOutput) {
            delegate?.qrScannerDidFail(self, error: "failed to add output")
            self.dismiss(animated: true, completion: nil)
            return
        }
        
        captureSession.addOutput(dataOutput)
        dataOutput.metadataObjectTypes = dataOutput.availableMetadataObjectTypes
        dataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    }
    
    private func addVideoPreviewLayer(_ view: UIView) {
        videoPreviewLayer.frame = CGRect(x:view.bounds.origin.x, y: view.bounds.origin.y, width: view.bounds.size.width, height: view.bounds.size.height - bottomSpace)
        view.layer.insertSublayer(videoPreviewLayer, at: 0)
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        for data in metadataObjects {
            let transformed = videoPreviewLayer.transformedMetadataObject(for: data) as? AVMetadataMachineReadableCodeObject
            if let unwraped = transformed {
                if view.bounds.contains(unwraped.bounds) {
                    delCnt = delCnt + 1
                    if delCnt > delayCount {
                        if let unwrapedStringValue = unwraped.stringValue {
                            delegate?.qrScanner(self, scanDidComplete: unwrapedStringValue)
                        } else {
                            delegate?.qrScannerDidFail(self, error: "Empty string found")
                        }
                        captureSession.stopRunning()
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
}

extension QRCodeScannerController {
    
    override public var shouldAutorotate: Bool {
        return false
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return UIInterfaceOrientation.portrait
    }
}
