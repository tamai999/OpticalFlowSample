import UIKit

class OpticalFlowVisualizerFilter: CIFilter {
    /// 加工元のベクトル情報
    var inputImage: CIImage?
    
    private static var ciKernel: CIKernel?
    
    override init() {
        super.init()
        
        if Self.ciKernel == nil {
            guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib") else { return }
            do {
                let data = try Data(contentsOf: url)
                Self.ciKernel = try CIKernel(functionName: "flowView", fromMetalLibraryData: data)
            } catch  {
                return
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var outputImage : CIImage? {
        get {
            guard let input = inputImage else { return nil }
            guard let kernel = Self.ciKernel else { return nil }
            // CIKernel実行
            return kernel.apply(extent: input.extent,
                                roiCallback: { (index, rect) in
                                    return rect
                                },
                                arguments: [input])
        }
    }
}
