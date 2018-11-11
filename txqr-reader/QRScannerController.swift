import UIKit
import AVFoundation
import QuickLook
import Txqr

class QRScannerController: UIViewController {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    var decoder = TxqrNewDecoder()

    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var topbar: UIView!
    @IBOutlet var progressBar: UIProgressView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Get the back-facing camera for capturing videos
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: AVMediaType.video, position: .back)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Set the input device on the capture session.
            captureSession.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
            // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            
            // Start video capture.
            captureSession.startRunning()
            
            // Move the message label and top bar to the front
            view.bringSubview(toFront: messageLabel)
            view.bringSubview(toFront: topbar)
            
            // Initialize QR Code Frame to highlight the QR code
            qrCodeFrameView = UIView()
            
            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubview(toFront: qrCodeFrameView)
            }
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
    }

    var fileURL = URL(string: "") // we save downloaded file here, because QuickLook can only open from file
    
    func ShowPreview(data: Data?) {
        let quickLookController = QLPreviewController()
        quickLookController.dataSource = self
        
        do {
            // Get the documents directory
            let documentsDirectoryURL = try! FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            // Give the file a name and append it to the file path
            fileURL = documentsDirectoryURL.appendingPathComponent("downloaded.jpeg")
            // Write the pdf to disk
            try data?.write(to: fileURL!, options: .atomic)
            
            // Make sure the file can be opened and then present the pdf
            //if QLPreviewController.canPreview(fileURL as QLPreviewItem) {
            quickLookController.currentPreviewItemIndex = 0
            
            present(quickLookController, animated: true, completion: nil)
            //}
        } catch {
            print("Showing file: \(error).")
            
        }
    }
}

extension QRScannerController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }
    
        let complete = decoder?.isCompleted()
        if complete! {
            return
        }

        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                let str = metadataObj.stringValue!;
                do {
                    try decoder?.decodeChunk(str)
                } catch {
                    print("Decode chunk error: \(error).")
                }
                
                
                let complete = decoder?.isCompleted()
                let progress = decoder?.progress()
                let speed = decoder?.speed()
                let readInterval = decoder?.readInterval()
                print("Read interval", readInterval!)
                
                if complete! {
                    messageLabel.text = String(format: "Read complete! Speed: %@", speed!)
                    let str = decoder?.data()
                    let data = Data(base64Encoded: str!)
                    
                    ShowPreview(data: data)
                } else {
                    messageLabel.text = String(format: "%02d%% [%@] (%dms)", progress!, speed!, readInterval!)
                    progressBar.setProgress(Float(progress!), animated: true)
                }
            }
        }
    }
}

extension QRScannerController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return fileURL! as QLPreviewItem
    }
}
