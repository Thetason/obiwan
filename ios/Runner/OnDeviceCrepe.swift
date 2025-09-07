import Foundation
import CoreML

@available(iOS 13.0, *)
class OnDeviceCrepeRunner {
    static let shared = OnDeviceCrepeRunner()
    private var model: MLModel?
    private var inputName: String?
    private var f0KeyCandidates = ["f0", "frequency", "frequencies", "pitch", "output"]
    private var confKeyCandidates = ["confidence", "conf", "voicing", "confidence_raw"]

    private init() {
        _ = loadModel()
    }

    func loadModel() -> Bool {
        if model != nil { return true }
        // Try .mlmodelc or .mlpackage inside Models/, then dev relative paths
        var url = (
            Bundle.main.url(forResource: "CREPE", withExtension: "mlmodelc", subdirectory: "Models") ??
            Bundle.main.url(forResource: "CREPE", withExtension: "mlpackage", subdirectory: "Models") ??
            Bundle.main.url(forResource: "CREPE", withExtension: "mlmodelc") ??
            Bundle.main.url(forResource: "CREPE", withExtension: "mlpackage")
        )
        if url == nil {
            let fm = FileManager.default
            let cwd = fm.currentDirectoryPath
            let candidates = [
                cwd + "/ios/Runner/Models/CREPE.mlpackage",
                cwd + "/ios/Runner/Models/CREPE.mlmodelc",
            ]
            for p in candidates { if fm.fileExists(atPath: p) { url = URL(fileURLWithPath: p); break } }
        }
        if let url = url {
            do {
                model = try MLModel(contentsOf: url)
                if let firstInput = model?.modelDescription.inputDescriptionsByName.first {
                    inputName = firstInput.key
                }
                return true
            } catch {
                print("[OnDeviceCREPE] Failed to load model: \(error)")
                model = nil
                return false
            }
        } else {
            print("[OnDeviceCREPE] CREPE model not found in bundle")
            return false
        }
    }

    func analyzeWindow(samples: Data, sampleRate: Double) -> (Double, Double) {
        guard #available(iOS 13.0, *), let model = model, let inputName = inputName else {
            return (0.0, 0.0)
        }
        // Decode Float32 buffer
        let count = samples.count / 4
        var f0: Double = 0.0
        var conf: Double = 0.0
        samples.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let floatPtr = ptr.bindMemory(to: Float.self)
            let buffer = floatPtr
            do {
                let array = try MLMultiArray(shape: [NSNumber(value: count)], dataType: .float32)
                for i in 0..<count { array[i] = NSNumber(value: buffer[i]) }
                let provider = SimpleProvider(inputName: inputName, array: array)
                let pred = try model.prediction(from: provider)
                // Try to extract outputs
                if let (freq, confidence) = self.parseOutputs(features: pred) {
                    f0 = freq
                    conf = confidence
                }
            } catch {
                print("[OnDeviceCREPE] prediction failed: \(error)")
            }
        }
        return (f0, conf)
    }

    private func parseOutputs(features: MLFeatureProvider) -> (Double, Double)? {
        // Try known keys in order; if array, use median/max
        func median(_ xs: [Double]) -> Double {
            if xs.isEmpty { return 0.0 }
            let sorted = xs.sorted()
            return sorted[sorted.count/2]
        }

        var f0: Double = 0.0
        var conf: Double = 0.0

        // frequency candidate
        for key in f0KeyCandidates {
            if let val = features.featureValue(for: key) {
                if val.type == .multiArray, let arr = val.multiArrayValue {
                    var vec = [Double]()
                    for i in 0..<arr.count { vec.append(arr[i].doubleValue) }
                    f0 = median(vec.filter { $0 > 0 })
                    break
                } else if val.type == .double {
                    f0 = val.doubleValue
                    break
                }
            }
        }

        // confidence candidate
        for key in confKeyCandidates {
            if let val = features.featureValue(for: key) {
                if val.type == .multiArray, let arr = val.multiArrayValue {
                    var vec = [Double]()
                    for i in 0..<arr.count { vec.append(arr[i].doubleValue) }
                    conf = vec.max() ?? 0.0
                    break
                } else if val.type == .double {
                    conf = val.doubleValue
                    break
                }
            }
        }

        if f0 > 0 { return (f0, max(0.0, min(conf, 1.0))) }
        return nil
    }
}

@available(iOS 13.0, *)
fileprivate class SimpleProvider: MLFeatureProvider {
    let inputName: String
    let array: MLMultiArray
    init(inputName: String, array: MLMultiArray) {
        self.inputName = inputName
        self.array = array
    }
    var featureNames: Set<String> { [inputName] }
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == inputName { return MLFeatureValue(multiArray: array) }
        return nil
    }
}
