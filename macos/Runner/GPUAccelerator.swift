import Foundation
import Metal
import MetalPerformanceShaders
import Accelerate

/// 고성능 GPU 가속 FFT 처리기 (Metal Performance Shaders + 커스텀 커널)
class GPUAccelerator {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private var fftSetup: vDSP_DFT_Setup?
    
    // Metal 커널 함수들
    private var fftRealToComplexKernel: MTLComputePipelineState?
    private var fftButterflyKernel: MTLComputePipelineState?
    private var powerSpectrumKernel: MTLComputePipelineState?
    private var findPeakKernel: MTLComputePipelineState?
    private var autocorrelationKernel: MTLComputePipelineState?
    private var windowKernel: MTLComputePipelineState?
    
    // 재사용 가능한 버퍼들
    private var bufferCache: [String: MTLBuffer] = [:]
    private let maxBufferSize = 16384 * MemoryLayout<Float>.stride
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            print("❌ Metal 디바이스 초기화 실패")
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Metal 셰이더 라이브러리 로드
        guard let library = device.makeDefaultLibrary() else {
            print("❌ Metal 라이브러리 로드 실패")
            return nil
        }
        self.library = library
        
        // 커널 파이프라인 초기화
        setupKernels()
        
        // Accelerate FFT 설정
        let log2n = 13 // 8192 샘플 (더 높은 해상도)
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(1 << log2n),
            vDSP_DFT_Direction.FORWARD
        )
    }
    
    private func setupKernels() {
        do {
            // FFT 관련 커널들
            if let function = library.makeFunction(name: "fft_real_to_complex") {
                fftRealToComplexKernel = try device.makeComputePipelineState(function: function)
            }
            
            if let function = library.makeFunction(name: "fft_butterfly") {
                fftButterflyKernel = try device.makeComputePipelineState(function: function)
            }
            
            if let function = library.makeFunction(name: "compute_power_spectrum") {
                powerSpectrumKernel = try device.makeComputePipelineState(function: function)
            }
            
            if let function = library.makeFunction(name: "find_peak_parallel") {
                findPeakKernel = try device.makeComputePipelineState(function: function)
            }
            
            if let function = library.makeFunction(name: "compute_autocorrelation") {
                autocorrelationKernel = try device.makeComputePipelineState(function: function)
            }
            
            if let function = library.makeFunction(name: "apply_window") {
                windowKernel = try device.makeComputePipelineState(function: function)
            }
            
            print("✅ Metal 커널 초기화 완료")
        } catch {
            print("❌ Metal 커널 초기화 실패: \(error)")
        }
    }
    
    /// 초고속 GPU 가속 FFT 실행 (Metal + Accelerate 하이브리드)
    func performFFT(audio: [Float], sampleRate: Float) -> [String: Any] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 버퍼 캐시에서 재사용 가능한 버퍼 가져오기
        let bufferKey = "audio_\(audio.count)"
        let audioBuffer = getCachedBuffer(key: bufferKey, size: audio.count * MemoryLayout<Float>.stride)
        
        guard let audioBuffer = audioBuffer else {
            return performFallbackFFT(audio: audio, sampleRate: sampleRate)
        }
        
        // 오디오 데이터 복사
        audioBuffer.contents().bindMemory(to: Float.self, capacity: audio.count)
            .initialize(from: audio, count: audio.count)
        
        // GPU에서 윈도우 함수 적용 (Hann 윈도우)
        let windowedBuffer = getCachedBuffer(key: "windowed_\(audio.count)", size: audio.count * MemoryLayout<Float>.stride)
        if let windowedBuffer = windowedBuffer,
           let windowKernel = windowKernel,
           let commandBuffer = commandQueue.makeCommandBuffer(),
           let encoder = commandBuffer.makeComputeCommandEncoder() {
            
            encoder.setComputePipelineState(windowKernel)
            encoder.setBuffer(audioBuffer, offset: 0, index: 0)
            encoder.setBuffer(windowedBuffer, offset: 0, index: 1)
            var length = UInt32(audio.count)
            var windowType = UInt32(0) // Hann window
            encoder.setBytes(&length, length: MemoryLayout<UInt32>.size, index: 2)
            encoder.setBytes(&windowType, length: MemoryLayout<UInt32>.size, index: 3)
            
            let threadsPerGroup = MTLSize(width: min(256, audio.count), height: 1, depth: 1)
            let numGroups = MTLSize(width: (audio.count + 255) / 256, height: 1, depth: 1)
            
            encoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        // Metal Performance Shaders FFT 사용 (최고 성능)
        let mpsFFT = MPSMatrixRealFFT(device: device, length: audio.count)
        
        // 복소수 결과 버퍼
        let complexCount = audio.count / 2 + 1
        let complexBuffer = getCachedBuffer(key: "complex_\(complexCount)", 
                                          size: complexCount * 2 * MemoryLayout<Float>.stride)
        
        if let complexBuffer = complexBuffer,
           let commandBuffer = commandQueue.makeCommandBuffer() {
            
            // MPS FFT 실행
            let inputMatrix = MPSMatrix(buffer: windowedBuffer ?? audioBuffer, 
                                      descriptor: MPSMatrixDescriptor(rows: 1, columns: audio.count, dataType: .float32))
            let outputMatrix = MPSMatrix(buffer: complexBuffer, 
                                       descriptor: MPSMatrixDescriptor(rows: 1, columns: complexCount * 2, dataType: .float32))
            
            mpsFFT.encode(commandBuffer: commandBuffer, inputMatrix: inputMatrix, resultMatrix: outputMatrix)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // 파워 스펙트럼 계산 (GPU)
            let powerBuffer = getCachedBuffer(key: "power_\(complexCount)", 
                                            size: complexCount * MemoryLayout<Float>.stride)
            
            if let powerBuffer = powerBuffer,
               let powerKernel = powerSpectrumKernel,
               let commandBuffer2 = commandQueue.makeCommandBuffer(),
               let encoder = commandBuffer2.makeComputeCommandEncoder() {
                
                encoder.setComputePipelineState(powerKernel)
                encoder.setBuffer(complexBuffer, offset: 0, index: 0)
                encoder.setBuffer(powerBuffer, offset: 0, index: 1)
                var n = UInt32(complexCount)
                encoder.setBytes(&n, length: MemoryLayout<UInt32>.size, index: 2)
                
                let threadsPerGroup = MTLSize(width: min(256, complexCount), height: 1, depth: 1)
                let numGroups = MTLSize(width: (complexCount + 255) / 256, height: 1, depth: 1)
                
                encoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
                encoder.endEncoding()
                commandBuffer2.commit()
                commandBuffer2.waitUntilCompleted()
                
                // 결과 읽기 및 피크 찾기
                let powerData = powerBuffer.contents().bindMemory(to: Float.self, capacity: complexCount)
                let powerArray = Array(UnsafeBufferPointer(start: powerData, count: complexCount))
                
                // 피크 찾기 (GPU 병렬 처리)
                let (maxValue, maxIndex) = findPeakGPU(powerArray, powerBuffer: powerBuffer)
                
                // 주파수 계산
                let binFrequency = sampleRate / Float(audio.count)
                var frequency = Float(maxIndex) * binFrequency
                
                // Parabolic interpolation
                if maxIndex > 0 && maxIndex < powerArray.count - 1 {
                    let y1 = powerArray[maxIndex - 1]
                    let y2 = powerArray[maxIndex]
                    let y3 = powerArray[maxIndex + 1]
                    
                    let x0 = (y3 - y1) / (2 * (2 * y2 - y1 - y3))
                    frequency += x0 * binFrequency
                }
                
                // 신뢰도 계산
                let totalEnergy = powerArray.reduce(0, +)
                let confidence = totalEnergy > 0 ? maxValue / totalEnergy : 0
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let latency = (endTime - startTime) * 1000
                
                print("✅ 초고속 GPU FFT 완료: \(frequency)Hz, 레이턴시: \(String(format: "%.2f", latency))ms")
                
                return [
                    "frequency": frequency,
                    "confidence": confidence,
                    "latency": latency
                ]
            }
        }
        
        // GPU 실패시 폴백
        return performFallbackFFT(audio: audio, sampleRate: sampleRate)
    }
    
    /// 버퍼 캐시 관리
    private func getCachedBuffer(key: String, size: Int) -> MTLBuffer? {
        if let cached = bufferCache[key], cached.length >= size {
            return cached
        }
        
        guard let newBuffer = device.makeBuffer(length: size, options: .storageModeShared) else {
            return nil
        }
        
        bufferCache[key] = newBuffer
        return newBuffer
    }
    
    /// GPU 병렬 피크 찾기
    private func findPeakGPU(_ array: [Float], powerBuffer: MTLBuffer) -> (Float, Int) {
        guard let findPeakKernel = findPeakKernel,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return findPeakCPU(array)
        }
        
        let groupCount = (array.count + 255) / 256
        let maxBuffer = device.makeBuffer(length: groupCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        let idxBuffer = device.makeBuffer(length: groupCount * MemoryLayout<UInt32>.stride, options: .storageModeShared)
        
        guard let maxBuffer = maxBuffer, let idxBuffer = idxBuffer else {
            return findPeakCPU(array)
        }
        
        encoder.setComputePipelineState(findPeakKernel)
        encoder.setBuffer(powerBuffer, offset: 0, index: 0)
        encoder.setBuffer(maxBuffer, offset: 0, index: 1)
        encoder.setBuffer(idxBuffer, offset: 0, index: 2)
        var n = UInt32(array.count)
        encoder.setBytes(&n, length: MemoryLayout<UInt32>.size, index: 3)
        encoder.setThreadgroupMemoryLength(256 * MemoryLayout<Float>.stride, index: 0)
        encoder.setThreadgroupMemoryLength(256 * MemoryLayout<UInt32>.stride, index: 1)
        
        let threadsPerGroup = MTLSize(width: 256, height: 1, depth: 1)
        let numGroups = MTLSize(width: groupCount, height: 1, depth: 1)
        
        encoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // 결과에서 최종 최대값 찾기
        let maxResults = maxBuffer.contents().bindMemory(to: Float.self, capacity: groupCount)
        let idxResults = idxBuffer.contents().bindMemory(to: UInt32.self, capacity: groupCount)
        
        var globalMax: Float = 0
        var globalIdx: Int = 0
        
        for i in 0..<groupCount {
            if maxResults[i] > globalMax {
                globalMax = maxResults[i]
                globalIdx = Int(idxResults[i])
            }
        }
        
        return (globalMax, globalIdx)
    }
    
    /// CPU 폴백 피크 찾기
    private func findPeakCPU(_ array: [Float]) -> (Float, Int) {
        var maxValue: Float = 0
        var maxIndex = 0
        
        for (index, value) in array.enumerated() {
            if value > maxValue {
                maxValue = value
                maxIndex = index
            }
        }
        
        return (maxValue, maxIndex)
    }
    
    /// 폴백 FFT (Accelerate)
    private func performFallbackFFT(audio: [Float], sampleRate: Float) -> [String: Any] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let n = vDSP_Length(audio.count)
        let log2n = vDSP_Length(log2(Float(n)))
        
        var realp = [Float](audio)
        var imagp = [Float](repeating: 0.0, count: audio.count)
        
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        // Accelerate FFT
        guard let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else {
            return ["frequency": 0.0, "confidence": 0.0, "latency": 0.0]
        }
        
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, Int32(FFT_FORWARD))
        vDSP_destroy_fftsetup(fftSetup)
        
        // 파워 스펙트럼
        var magnitudes = [Float](repeating: 0.0, count: audio.count/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(audio.count/2))
        
        // 피크 검출
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(magnitudes, 1, &maxValue, &maxIndex, vDSP_Length(magnitudes.count))
        
        let binFrequency = sampleRate / Float(audio.count)
        let frequency = Float(maxIndex) * binFrequency
        let totalEnergy = magnitudes.reduce(0, +)
        let confidence = totalEnergy > 0 ? maxValue / totalEnergy : 0
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let latency = (endTime - startTime) * 1000
        
        return [
            "frequency": frequency,
            "confidence": confidence,
            "latency": latency
        ]
    }
    
    /// Metal 셰이더를 사용한 병렬 자기상관
    func performAutocorrelation(audio: [Float], sampleRate: Float) -> Float {
        // Metal 버퍼 생성
        guard let audioBuffer = device.makeBuffer(
            bytes: audio,
            length: audio.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else { return 0 }
        
        let outputSize = audio.count / 2
        guard let outputBuffer = device.makeBuffer(
            length: outputSize * MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else { return 0 }
        
        // Compute pipeline 설정
        guard let function = library.makeFunction(name: "autocorrelation"),
              let pipeline = try? device.makeComputePipelineState(function: function),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            // Fallback to CPU
            return cpuAutocorrelation(audio: audio, sampleRate: sampleRate)
        }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(audioBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        
        var length = Int32(audio.count)
        encoder.setBytes(&length, length: MemoryLayout<Int32>.size, index: 2)
        
        // 스레드 그룹 설정
        let threadsPerGroup = MTLSize(width: 256, height: 1, depth: 1)
        let numGroups = MTLSize(
            width: (outputSize + 255) / 256,
            height: 1,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // 결과 읽기
        let result = outputBuffer.contents().bindMemory(
            to: Float.self,
            capacity: outputSize
        )
        
        // 피크 찾기
        var maxCorr: Float = 0
        var bestLag = 0
        
        for lag in 20..<outputSize {
            if result[lag] > maxCorr {
                maxCorr = result[lag]
                bestLag = lag
            }
        }
        
        return bestLag > 0 ? sampleRate / Float(bestLag) : 0
    }
    
    /// CPU 폴백 자기상관
    private func cpuAutocorrelation(audio: [Float], sampleRate: Float) -> Float {
        let minLag = 20
        let maxLag = min(audio.count / 2, Int(sampleRate / 50))
        
        var maxCorr: Float = 0
        var bestLag = 0
        
        // vDSP를 사용한 벡터화된 자기상관
        for lag in minLag..<maxLag {
            var correlation: Float = 0
            vDSP_dotpr(
                audio,
                1,
                audio.dropFirst(lag),
                1,
                &correlation,
                vDSP_Length(audio.count - lag)
            )
            
            if correlation > maxCorr {
                maxCorr = correlation
                bestLag = lag
            }
        }
        
        return bestLag > 0 ? sampleRate / Float(bestLag) : 0
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
}

/// Metal 셰이더 함수 (별도 .metal 파일로 분리 가능)
/*
kernel void autocorrelation(
    device const float* audio [[buffer(0)]],
    device float* output [[buffer(1)]],
    constant int& length [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= length / 2) return;
    
    float sum = 0.0;
    int lag = id + 1;
    
    for (int i = 0; i < length - lag; i++) {
        sum += audio[i] * audio[i + lag];
    }
    
    output[id] = sum;
}
*/