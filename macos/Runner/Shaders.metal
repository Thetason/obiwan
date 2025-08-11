#include <metal_stdlib>
using namespace metal;

/// Metal FFT 커널 - 고성능 병렬 처리
kernel void fft_real_to_complex(
    device const float* real_input [[buffer(0)]],
    device float2* complex_output [[buffer(1)]],
    constant uint& n [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= n) return;
    
    // 실수 -> 복소수 변환
    complex_output[id] = float2(real_input[id], 0.0);
}

/// Radix-2 FFT 버터플라이 연산
kernel void fft_butterfly(
    device float2* data [[buffer(0)]],
    constant uint& n [[buffer(1)]],
    constant uint& stage [[buffer(2)]],
    constant uint& group_size [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    uint total_groups = n / group_size;
    if (id >= total_groups * group_size / 2) return;
    
    uint group_id = id / (group_size / 2);
    uint local_id = id % (group_size / 2);
    
    uint base = group_id * group_size;
    uint i = base + local_id;
    uint j = i + group_size / 2;
    
    // Twiddle factor 계산
    float angle = -2.0 * M_PI_F * local_id / group_size;
    float2 twiddle = float2(cos(angle), sin(angle));
    
    // 버터플라이 연산
    float2 temp = data[j] * twiddle;
    data[j] = data[i] - temp;
    data[i] = data[i] + temp;
}

/// 파워 스펙트럼 계산
kernel void compute_power_spectrum(
    device const float2* complex_input [[buffer(0)]],
    device float* power_output [[buffer(1)]],
    constant uint& n [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= n / 2) return;
    
    float2 complex_val = complex_input[id];
    power_output[id] = complex_val.x * complex_val.x + complex_val.y * complex_val.y;
}

/// 피크 찾기 (병렬 리덕션)
kernel void find_peak_parallel(
    device const float* magnitudes [[buffer(0)]],
    device float* max_values [[buffer(1)]],
    device uint* max_indices [[buffer(2)]],
    constant uint& n [[buffer(3)]],
    uint id [[thread_position_in_grid]],
    uint local_id [[thread_position_in_threadgroup]],
    threadgroup float* shared_max [[threadgroup(256)]],
    threadgroup uint* shared_idx [[threadgroup(256)]]
) {
    // 로컬 최대값 찾기
    shared_max[local_id] = (id < n) ? magnitudes[id] : 0.0;
    shared_idx[local_id] = id;
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 리덕션
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (local_id < stride && local_id + stride < 256) {
            if (shared_max[local_id + stride] > shared_max[local_id]) {
                shared_max[local_id] = shared_max[local_id + stride];
                shared_idx[local_id] = shared_idx[local_id + stride];
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // 결과 저장
    if (local_id == 0) {
        uint group_id = id / 256;
        max_values[group_id] = shared_max[0];
        max_indices[group_id] = shared_idx[0];
    }
}

/// 자기상관 계산 (GPU 최적화)
kernel void compute_autocorrelation(
    device const float* audio [[buffer(0)]],
    device float* output [[buffer(1)]],
    constant int& length [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= length / 2) return;
    
    float sum = 0.0;
    int lag = id + 1;
    
    // 벡터화된 내적 계산
    for (int i = 0; i < length - lag; i += 4) {
        float4 a = float4(audio[i], audio[i+1], audio[i+2], audio[i+3]);
        float4 b = float4(audio[i+lag], audio[i+lag+1], audio[i+lag+2], audio[i+lag+3]);
        sum += dot(a, b);
    }
    
    output[id] = sum;
}

/// 윈도우 함수 적용 (Hann, Hamming, Blackman)
kernel void apply_window(
    device const float* input [[buffer(0)]],
    device float* output [[buffer(1)]],
    constant uint& n [[buffer(2)]],
    constant uint& window_type [[buffer(3)]], // 0: Hann, 1: Hamming, 2: Blackman
    uint id [[thread_position_in_grid]]
) {
    if (id >= n) return;
    
    float window_val = 1.0;
    float phase = 2.0 * M_PI_F * id / (n - 1);
    
    switch (window_type) {
        case 0: // Hann
            window_val = 0.5 * (1.0 - cos(phase));
            break;
        case 1: // Hamming
            window_val = 0.54 - 0.46 * cos(phase);
            break;
        case 2: // Blackman
            window_val = 0.42 - 0.5 * cos(phase) + 0.08 * cos(2.0 * phase);
            break;
    }
    
    output[id] = input[id] * window_val;
}

/// 실시간 스펙트로그램 업데이트
kernel void update_spectrogram(
    device const float* new_spectrum [[buffer(0)]],
    device float* spectrogram [[buffer(1)]],
    constant uint& width [[buffer(2)]],
    constant uint& height [[buffer(3)]],
    constant uint& current_column [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= height) return;
    
    // 새로운 스펙트럼 데이터를 스펙트로그램에 추가
    uint spectrum_index = (id * new_spectrum[0]) / height; // 첫 번째 요소를 길이로 사용
    if (spectrum_index < new_spectrum[0]) {
        spectrogram[current_column * height + id] = new_spectrum[spectrum_index + 1];
    }
}