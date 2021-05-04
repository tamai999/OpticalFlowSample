import UIKit
import Vision
import AVFoundation

fileprivate enum Const {
    static let buttonStartTitle = "観察開始"
    static let buttonStopTitle = "停止"
}

class ViewController: UIViewController {

    @IBOutlet weak var preview: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var startButton: UIButton!
    
    // キャプチャ画像サイズ
    private var videoWidth = 0
    private var videoHeight = 0
    
    // キャプチャ画像の入出力
    private var rootLayer: CALayer! = nil
    private let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput",
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    
    // オプティカルフロー算出
    var requestHandler = VNSequenceRequestHandler()
    var savedImage: CGImage?
    // 独自フィルタ
    let ciFilter = OpticalFlowVisualizerFilter()
    
    var isMonitoring = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupAVCapture()

        // キャプチャ開始
        session.startRunning()
    }

    @IBAction func startButtonTapped(_ sender: Any) {
        isMonitoring = !isMonitoring
        if isMonitoring {
            startButton.setTitle(Const.buttonStopTitle, for: .normal)
        } else {
            startButton.setTitle(Const.buttonStartTitle, for: .normal)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // キャプチャ画像を取得
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard let newImage = sampleBuffer.rightRotatedCgImage else { return }
        
        if let saved = savedImage {
            let savedCIImage = CIImage(cgImage: saved)
            // オプティカルフローを可視化した画像を取得
            if let opticalFlowImage = makeOpticalFlowImage(baseImage: savedCIImage, newImage: newImage) {
                DispatchQueue.main.async {
                    self.imageView.image = UIImage(ciImage: opticalFlowImage)
                }
            }
        }
        
        if !isMonitoring {
            savedImage = newImage
        }
    }
}

// MARK: - private

private extension ViewController {
    
    func setupView() {
        imageView.contentMode = .scaleAspectFill
        startButton.setTitle(Const.buttonStartTitle, for: .normal)
    }
    
    func setupAVCapture() {
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                           mediaType: .video,
                                                           position: .back).devices.first
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice!) else { return }
        // capture セッション セットアップ
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        
        // 入力デバイス指定
        session.addInput(deviceInput)
        
        // 出力先の設定
        session.addOutput(videoDataOutput)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        let captureConnection = videoDataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
        
        // ビデオの画像サイズ取得
        try? videoDevice!.lockForConfiguration()
        let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
        videoWidth = Int(dimensions.width)
        videoHeight = Int(dimensions.height)
        videoDevice!.unlockForConfiguration()
        
        session.commitConfiguration()
        
        // プレビューセットアップ
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = preview.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
    }
    
    /// オプティカルフローの取得、及び、可視化をする
    /// - Parameters:
    ///   - baseImage: フローの元とする画像
    ///   - newImage: フローの先となる画像
    /// - Returns: フローを三角形で可視化した画像
    func makeOpticalFlowImage(baseImage: CIImage, newImage: CGImage) -> CIImage? {
        // オプティカルフローを取得
        var opticalFlow: CIImage?
        do {
            let request = VNGenerateOpticalFlowRequest(targetedCGImage: newImage, options: [:])
            try self.requestHandler.perform([request], on: baseImage)
            
            guard let pixelBufferObservation = request.results?.first as? VNPixelBufferObservation else { return nil }
            opticalFlow = CIImage(cvImageBuffer: pixelBufferObservation.pixelBuffer)
        } catch {
            return nil
        }
        
        // オプティカルフローを可視化する。
        ciFilter.inputImage = opticalFlow
        return ciFilter.outputImage
    }
}
