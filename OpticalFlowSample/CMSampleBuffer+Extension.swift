import AVFoundation
import UIKit

extension CMSampleBuffer {
    /// CMSampleBuffer -> CGImage 変換
    var rightRotatedCgImage: CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }

        // 入力画像が90回転しているので元に戻す。
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let pixelBufferWidth = CGFloat(CVPixelBufferGetHeight(pixelBuffer))  // 縦横の長さ入れ替わる
        let pixelBufferHeight = CGFloat(CVPixelBufferGetWidth(pixelBuffer))  // 縦横の長さ入れ替わる
        let imageRect:CGRect = CGRect(x: 0,y: 0,width: pixelBufferWidth, height: pixelBufferHeight)
        let ciContext = CIContext.init()
        
        return ciContext.createCGImage(ciImage, from: imageRect)
    }
}
