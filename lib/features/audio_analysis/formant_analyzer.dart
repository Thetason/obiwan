import 'dart:math' as math;
import 'package:fftea/fftea.dart';
import '../../domain/entities/vocal_analysis.dart';

class FormantAnalyzer {
  static const int lpcOrder = 10;
  static const int fftSize = 2048;
  static const double preEmphasisCoeff = 0.97;
  
  final int sampleRate;
  
  FormantAnalyzer({this.sampleRate = 16000});
  
  List<double> extractFormants(List<double> audioSamples) {
    if (audioSamples.length < fftSize) {
      return [700, 1500, 2500]; // 기본값
    }
    
    // 1. Pre-emphasis 필터 적용
    final preEmphasized = _applyPreEmphasis(audioSamples);
    
    // 2. 윈도우 함수 적용
    final windowed = _applyWindow(preEmphasized.sublist(0, fftSize));
    
    // 3. LPC 분석
    final lpcCoeffs = _computeLPC(windowed, lpcOrder);
    
    // 4. LPC 스펙트럼에서 포먼트 추출
    final formants = _findFormants(lpcCoeffs);
    
    // 5. 포먼트 유효성 검증 및 정렬
    return _validateFormants(formants);
  }
  
  ResonancePosition classifyResonance(List<double> formants) {
    if (formants.length < 3) return ResonancePosition.throat;
    
    final f1 = formants[0];
    final f2 = formants[1];
    final f3 = formants[2];
    
    // Singer's formant 검출 (2500-3500 Hz)
    final singerFormantStrength = _detectSingerFormant(formants);
    
    // 포먼트 비율 계산
    final f2f1Ratio = f2 / f1;
    final f3f2Ratio = f3 / f2;
    final f3f1Ratio = f3 / f1;
    
    // 공명 위치 분류
    if (singerFormantStrength > 0.7) {
      return ResonancePosition.mixed; // 전문 가수의 혼합 공명
    } else if (f1 < 600 && f2f1Ratio < 2.5) {
      return ResonancePosition.throat; // 목 공명
    } else if (f1 > 700 && f2 > 1800 && f3f2Ratio > 1.4) {
      return ResonancePosition.head; // 두성
    } else if (f2 > 1200 && f2 < 1800 && f3f1Ratio > 3.5) {
      return ResonancePosition.mouth; // 구강 공명
    } else {
      return ResonancePosition.mixed;
    }
  }
  
  List<double> _applyPreEmphasis(List<double> samples) {
    final output = List<double>.filled(samples.length, 0.0);
    output[0] = samples[0];
    
    for (int i = 1; i < samples.length; i++) {
      output[i] = samples[i] - preEmphasisCoeff * samples[i - 1];
    }
    
    return output;
  }
  
  List<double> _applyWindow(List<double> samples) {
    final windowed = List<double>.filled(samples.length, 0.0);
    
    for (int i = 0; i < samples.length; i++) {
      // Hamming window
      final window = 0.54 - 0.46 * math.cos(2 * math.pi * i / (samples.length - 1));
      windowed[i] = samples[i] * window;
    }
    
    return windowed;
  }
  
  List<double> _computeLPC(List<double> samples, int order) {
    // Levinson-Durbin 알고리즘을 사용한 LPC 계수 계산
    final r = _computeAutocorrelation(samples, order + 1);
    final a = List<double>.filled(order + 1, 0.0);
    final e = List<double>.filled(order + 1, 0.0);
    
    a[0] = 1.0;
    e[0] = r[0];
    
    for (int i = 1; i <= order; i++) {
      double lambda = 0.0;
      for (int j = 1; j < i; j++) {
        lambda += a[j] * r[i - j];
      }
      lambda = (r[i] + lambda) / e[i - 1];
      
      // 계수 업데이트
      final temp = List<double>.from(a);
      for (int j = 1; j < i; j++) {
        a[j] = temp[j] - lambda * temp[i - j];
      }
      a[i] = -lambda;
      e[i] = e[i - 1] * (1 - lambda * lambda);
    }
    
    return a;
  }
  
  List<double> _computeAutocorrelation(List<double> samples, int maxLag) {
    final r = List<double>.filled(maxLag, 0.0);
    
    for (int lag = 0; lag < maxLag; lag++) {
      double sum = 0.0;
      for (int i = 0; i < samples.length - lag; i++) {
        sum += samples[i] * samples[i + lag];
      }
      r[lag] = sum;
    }
    
    return r;
  }
  
  List<double> _findFormants(List<double> lpcCoeffs) {
    // LPC 계수로부터 주파수 응답 계산
    final frequencies = <double>[];
    final magnitudes = <double>[];
    
    for (int i = 0; i < fftSize ~/ 2; i++) {
      final freq = i * sampleRate / fftSize;
      final omega = 2 * math.pi * freq / sampleRate;
      
      // LPC 전달함수 H(z) = 1 / A(z) 계산
      var realPart = 0.0;
      var imagPart = 0.0;
      
      for (int k = 0; k < lpcCoeffs.length; k++) {
        realPart += lpcCoeffs[k] * math.cos(k * omega);
        imagPart -= lpcCoeffs[k] * math.sin(k * omega);
      }
      
      final magnitude = 1.0 / math.sqrt(realPart * realPart + imagPart * imagPart);
      
      frequencies.add(freq);
      magnitudes.add(magnitude);
    }
    
    // 피크 검출
    final peaks = <double>[];
    for (int i = 1; i < magnitudes.length - 1; i++) {
      if (magnitudes[i] > magnitudes[i - 1] && 
          magnitudes[i] > magnitudes[i + 1] &&
          frequencies[i] > 200 && frequencies[i] < 4000) {
        peaks.add(frequencies[i]);
      }
    }
    
    // 상위 4개 피크 선택
    peaks.sort();
    return peaks.take(4).toList();
  }
  
  List<double> _validateFormants(List<double> formants) {
    final validated = <double>[];
    
    // F1: 200-1000 Hz
    if (formants.isNotEmpty) {
      final f1 = formants.firstWhere(
        (f) => f >= 200 && f <= 1000,
        orElse: () => 700,
      );
      validated.add(f1);
    } else {
      validated.add(700);
    }
    
    // F2: 600-3000 Hz
    if (formants.length > 1) {
      final f2 = formants.firstWhere(
        (f) => f >= 600 && f <= 3000 && f > validated[0],
        orElse: () => 1500,
      );
      validated.add(f2);
    } else {
      validated.add(1500);
    }
    
    // F3: 1500-4000 Hz
    if (formants.length > 2) {
      final f3 = formants.firstWhere(
        (f) => f >= 1500 && f <= 4000 && f > validated[1],
        orElse: () => 2500,
      );
      validated.add(f3);
    } else {
      validated.add(2500);
    }
    
    // F4: 2500-5000 Hz (선택적)
    if (formants.length > 3) {
      final f4 = formants.firstWhere(
        (f) => f >= 2500 && f <= 5000 && f > validated[2],
        orElse: () => 3500,
      );
      validated.add(f4);
    }
    
    return validated;
  }
  
  double _detectSingerFormant(List<double> formants) {
    // Singer's formant는 보통 2500-3500 Hz 사이에 나타남
    const singerFormantMin = 2500.0;
    const singerFormantMax = 3500.0;
    
    for (final formant in formants) {
      if (formant >= singerFormantMin && formant <= singerFormantMax) {
        // 정규화된 강도 반환 (0-1)
        return 1.0;
      }
    }
    
    // F3와 F4 사이의 클러스터링 검출
    if (formants.length >= 4) {
      final f3 = formants[2];
      final f4 = formants[3];
      
      if (f4 - f3 < 500 && f3 > 2000) {
        return 0.8;
      }
    }
    
    return 0.0;
  }
  
  // 포먼트 대역폭 계산
  List<double> calculateBandwidths(List<double> audioSamples, List<double> formants) {
    final bandwidths = <double>[];
    
    // 각 포먼트에 대한 대역폭 추정
    for (final formant in formants) {
      // 간단한 추정: 포먼트 주파수에 비례
      final bandwidth = formant * 0.1; // 10% 규칙
      bandwidths.add(bandwidth);
    }
    
    return bandwidths;
  }
}