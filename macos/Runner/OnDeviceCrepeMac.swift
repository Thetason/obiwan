import Foundation
import CoreML

@available(macOS 11.0, *)
class MacOnDeviceCrepeRunner {
  static let shared = MacOnDeviceCrepeRunner()
  private var model: MLModel?
  private var inputName: String?
  private init() { _ = loadModel() }

  func loadModel() -> Bool {
    if model != nil { return true }
    let bundle = Bundle.main
    let url = (
      bundle.url(forResource: "CREPE", withExtension: "mlmodelc", subdirectory: "Models") ??
      bundle.url(forResource: "CREPE", withExtension: "mlpackage", subdirectory: "Models") ??
      bundle.url(forResource: "CREPE", withExtension: "mlmodelc") ??
      bundle.url(forResource: "CREPE", withExtension: "mlpackage")
    )
    var murlOpt = url
    if murlOpt == nil {
      // Fallback: search common relative paths during dev
      let fm = FileManager.default
      let cwd = fm.currentDirectoryPath
      let candidates = [
        cwd + "/macos/Runner/Models/CREPE.mlpackage",
        cwd + "/macos/Runner/Models/CREPE.mlmodelc",
        cwd + "/ios/Runner/Models/CREPE.mlpackage",
        cwd + "/ios/Runner/Models/CREPE.mlmodelc",
      ]
      for p in candidates {
        if fm.fileExists(atPath: p) { murlOpt = URL(fileURLWithPath: p); break }
      }
    }
    guard let murl = murlOpt else { print("[MacCREPE] Model not found in bundle or dev paths"); return false }
    do {
      model = try MLModel(contentsOf: murl)
      if let first = model?.modelDescription.inputDescriptionsByName.first {
        inputName = first.key
      }
      print("[MacCREPE] Model loaded: \(murl)")
      return true
    } catch {
      print("[MacCREPE] Load error: \(error)")
      model = nil
      return false
    }
  }

  func analyzeWindow(samples: Data, sampleRate: Double) -> (Double, Double) {
    guard let model = model, let inputName = inputName else { return (0.0, 0.0) }
    let count = samples.count / 4
    var f0: Double = 0.0
    var conf: Double = 0.0
    samples.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      let fp = ptr.bindMemory(to: Float.self)
      do {
        let arr = try MLMultiArray(shape: [NSNumber(value: count)], dataType: .float32)
        for i in 0..<count { arr[i] = NSNumber(value: fp[i]) }
        let provider = MacSimpleProvider(inputName: inputName, array: arr)
        let out = try model.prediction(from: provider)
        if let val = out.featureValue(for: "f0")?.doubleValue { f0 = val }
        if let v = out.featureValue(for: "confidence")?.doubleValue { conf = v }
        if f0 <= 0 {
          for k in ["frequency","frequencies","pitch","output"] {
            if let mv = out.featureValue(for: k)?.multiArrayValue {
              var vec = [Double]()
              for i in 0..<mv.count { vec.append(mv[i].doubleValue) }
              let filtered = vec.filter{ $0 > 0 }
              if !filtered.isEmpty { f0 = filtered.sorted()[filtered.count/2]; break }
            }
          }
        }
        if conf == 0 {
          for k in ["confidence_raw","voicing","conf"] {
            if let mv = out.featureValue(for: k)?.multiArrayValue {
              var mx = 0.0
              for i in 0..<mv.count { mx = max(mx, mv[i].doubleValue) }
              conf = mx; break
            }
          }
        }
      } catch {
        print("[MacCREPE] prediction error: \(error)")
      }
    }
    return (f0, min(max(conf, 0.0), 1.0))
  }
}

@available(macOS 11.0, *)
fileprivate class MacSimpleProvider: MLFeatureProvider {
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
