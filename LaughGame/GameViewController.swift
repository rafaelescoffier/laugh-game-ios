//
//  ViewController.swift
//  LaughGame
//
//  Created by Rafael d'Escoffier on 04/07/17.
//  Copyright © 2017 Rafael Escoffier. All rights reserved.
//

import UIKit
import AVFoundation
import Kingfisher
import ReactiveSwift
import ReactiveCocoa

enum GameState {
    case initializing
    case fetching
    case fetched
    case loading
    case running
    case finished
    case ended
}

class GameViewController: UIViewController {
    @IBOutlet weak var captureView: UIView!
    @IBOutlet weak var gifImageView: UIImageView!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var activity: UIActivityIndicatorView!
    @IBOutlet weak var messageLabel: UILabel!
    
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var captureSession:AVCaptureSession?
    var captureOutput: AVCaptureVideoDataOutput?
    var faceDetector: CIDetector?
    
    let laughTotal = 5
    
    let categories = ["funny dog" , "funny cat", "funny falls", "funny animals"]
    
    fileprivate let stateQueue = DispatchQueue(label: "stateQueue", attributes: .concurrent)

    fileprivate var collection: [Giphy]?
    
    fileprivate var laughs: [Int] = []
    
    fileprivate var score = MutableProperty(0.0)
    fileprivate var state = MutableProperty(GameState.initializing)

    fileprivate var scanning = false
    fileprivate var frameCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scoreLabel.reactive.text <~ score
            .signal
            .filter{ _ in self.state.value == .running || self.state.value == .loading }
            .observe(on: UIScheduler())
            .map { score in
                switch score {
                case 0.0 ..< 0.25: return "Why so serious!!! 😐"
                case 0.25 ..< 0.5: return "I think i saw a laught!!! 🙂"
                default: return "Oh, I saw you laughing!!! 😀"
                }
        }
        
        activity.reactive.isHidden <~ state
            .signal
            .observe(on: UIScheduler()).map { state in
                switch state {
                case .running, .finished: return true
                default: return false
                }
        }
        
        messageLabel.reactive.text <~ state.signal.observe(on: UIScheduler()).map { state in
            switch state {
            case .fetching: return "Fetching content..."
            case .loading: return "Loading GIF..."
            case .finished: return "You lost!"
            default: return ""
            }
        }
        
        state.producer.observe(on: UIScheduler()).startWithValues { [weak self] state in
            self?.changeCaptureStatus(state: state)
            self?.handleState(state: state)
        }
        
        score.producer.observe(on: UIScheduler()).startWithValues { [weak self] score in
            self?.finishGame(score: score)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupCapture()
        fetchContent()
    }
    
    @IBAction func backPressed(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    fileprivate func fetchContent() {
        state.value = .fetching
        
        let query = categories[Int(arc4random()) % categories.count]
        
        GiphyAPI.search(query: query) { (collection) in
            self.collection = collection
            
            self.state.value = .loading
        }
    }
    
    fileprivate func addLaugh(value: Int) {
        laughs.append(value)
        
        if laughs.count == laughTotal {
            score.value = Double(laughs.reduce(0) { $0.0 + $0.1 }) / Double(laughTotal)
            
            laughs.removeAll(keepingCapacity: true)
        }
    }

    
    fileprivate func loadNextGIF() {
        stopCapture()
        
        let url = URL(string: collection![Int(arc4random()) % collection!.count].url)!
        
        self.gifImageView.kf.setImage(with: url) { _ in
            self.state.value = .running
        }
    }
    
    fileprivate func running() {
        startCapture()
        
        stateQueue.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let strongSelf = self else { return }
            
            if strongSelf.state.value == .running {
                strongSelf.state.value = .loading
            }
        }
    }
    
    fileprivate func finish() {
        DispatchQueue.main.sync { [weak self] in
            self?.gifImageView.image = nil
            
            let vc = UIAlertController(title: "You lost!", message: "We saw you laughing 😀", preferredStyle: .alert)
            
            let action = UIAlertAction(title: "Restart", style: .default) { _ in
                self?.navigationController?.popViewController(animated: true)
            }
            
            vc.addAction(action)
            
            self?.present(vc, animated: true, completion: nil)
        }
    }
    
    deinit {
        print("DENIT \(self)")
    }
}

// MARK: - Map Functions
extension GameViewController {
    fileprivate func handleState(state: GameState) {
        stateQueue.async {
            switch state {
            case .loading:
                self.loadNextGIF()
            case .running:
                self.running()
            case .finished:
                self.finish()
            default:
                break
            }
        }
    }
    
    fileprivate func finishGame(score: Double) {
        if score > 0.5 && state.value == .running {
            state.value = .finished
        }
    }
    
    fileprivate func changeCaptureStatus(state: GameState) {
        switch state {
        case .running: self.startCapture()
        default: self.stopCapture()
        }
    }
    
    fileprivate func mapActivityVisibility(state: GameState) -> Bool {
        switch state {
        case .running, .finished: return true
        default: return false
        }
    }
    
    fileprivate func mapScoreText(score: Double) -> String {
        switch score {
        case 0.0 ..< 0.3: return "Why so serious!!! 😐"
        case 0.3 ..< 0.6: return "I think i saw a laught!!! 🙂"
        default: return "Oh, I saw you laughing!!! 😀"
        }
    }
    
    fileprivate func mapStateText(state: GameState) -> String? {
        switch state {
        case .fetching: return "Fetching content..."
        case .loading: return "Loading GIF..."
        case .finished: return "You lost!"
        default: return nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension GameViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    fileprivate func startCapture() {
        if !scanning {
            captureSession?.startRunning()
            scanning = true
        }
    }
    
    fileprivate func stopCapture() {
        if scanning {
            captureSession?.stopRunning()
            scanning = false
        }
    }
    
    fileprivate func setupCapture() {
        
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video
        // as the media type parameter.
        guard let captureDevice = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)[1] as? AVCaptureDevice else {
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Initialize the captureSession object.
            captureSession = AVCaptureSession()
            
            captureSession?.sessionPreset = AVCaptureSessionPresetMedium
            // Set the input device on the capture session.
            captureSession?.addInput(input)
            
            faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureOutput = AVCaptureVideoDataOutput()
            
            captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            captureOutput.alwaysDiscardsLateVideoFrames = true
            
            self.captureOutput = captureOutput
            
            let queue = DispatchQueue(label: "output.queue")
            captureOutput.setSampleBufferDelegate(self, queue: queue)
            
            captureSession?.addOutput(captureOutput)
            captureSession?.commitConfiguration()
        } catch let error as NSError {
            // If any error occurs, simply print it out and don't continue any more.
            print("QRCode scan failed with error \(error)")

        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        guard frameCount == 3 else {
            frameCount += 1
            
            return
        }
        
        frameCount = 0
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        let options: [String : Any] = [CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation),
                                       CIDetectorSmile: true]
        
        let allFeatures = faceDetector?.features(in: ciImage, options: options)
        
        guard let features = allFeatures else { return }
        
        for feature in features {
            if let faceFeature = feature as? CIFaceFeature {
                addLaugh(value: faceFeature.hasSmile ? 1 : 0)
                print(faceFeature.hasSmile)
            }
        }
    }
    
    private func exifOrientation(orientation: UIDeviceOrientation) -> Int {
        switch orientation {
        case .portraitUpsideDown:
            return 8
        case .landscapeLeft:
            return 3
        case .landscapeRight:
            return 1
        default:
            return 6
        }
    }
}
