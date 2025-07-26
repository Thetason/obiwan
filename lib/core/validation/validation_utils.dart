import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../error_handling/error_handler.dart';

/// Comprehensive validation utilities for the vocal trainer application
class ValidationUtils {
  static final ValidationUtils _instance = ValidationUtils._internal();
  factory ValidationUtils() => _instance;
  ValidationUtils._internal();
  
  /// Validate audio data input
  ValidationResult validateAudioData(List<double>? audioData) {
    if (audioData == null) {
      return ValidationResult.failure('Audio data cannot be null');
    }
    
    if (audioData.isEmpty) {
      return ValidationResult.failure('Audio data cannot be empty');
    }
    
    if (audioData.length < 100) {
      return ValidationResult.failure('Audio data too short (minimum 100 samples required)');
    }
    
    if (audioData.length > 1000000) {
      return ValidationResult.failure('Audio data too long (maximum 1M samples allowed)');
    }
    
    // Check for invalid values
    final hasInvalidValues = audioData.any((sample) => 
        sample.isNaN || sample.isInfinite || sample.abs() > 10.0);
    
    if (hasInvalidValues) {
      return ValidationResult.failure('Audio data contains invalid values (NaN, Infinite, or > 10.0)');
    }
    
    // Check for silence (all zeros)
    final maxAmplitude = audioData.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    if (maxAmplitude < 1e-10) {
      return ValidationResult.failure('Audio data appears to be silent');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate Float32List audio data
  ValidationResult validateFloat32AudioData(Float32List? audioData) {
    if (audioData == null) {
      return ValidationResult.failure('Float32List audio data cannot be null');
    }
    
    return validateAudioData(audioData.toList());
  }
  
  /// Validate sample rate
  ValidationResult validateSampleRate(int? sampleRate) {
    if (sampleRate == null) {
      return ValidationResult.failure('Sample rate cannot be null');
    }
    
    const validSampleRates = [8000, 16000, 22050, 44100, 48000, 96000];
    
    if (!validSampleRates.contains(sampleRate)) {
      return ValidationResult.failure(
        'Invalid sample rate: $sampleRate. Valid rates: ${validSampleRates.join(', ')}'
      );
    }
    
    return ValidationResult.success();
  }
  
  /// Validate FFT size
  ValidationResult validateFFTSize(int? fftSize) {
    if (fftSize == null) {
      return ValidationResult.failure('FFT size cannot be null');
    }
    
    if (fftSize <= 0) {
      return ValidationResult.failure('FFT size must be positive');
    }
    
    // Check if power of 2
    if ((fftSize & (fftSize - 1)) != 0) {
      return ValidationResult.failure('FFT size must be a power of 2');
    }
    
    if (fftSize < 64) {
      return ValidationResult.failure('FFT size too small (minimum 64)');
    }
    
    if (fftSize > 16384) {
      return ValidationResult.failure('FFT size too large (maximum 16384)');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate frequency range
  ValidationResult validateFrequencyRange(double? minFreq, double? maxFreq, int? sampleRate) {
    if (minFreq == null || maxFreq == null) {
      return ValidationResult.failure('Frequency range cannot be null');
    }
    
    if (minFreq < 0) {
      return ValidationResult.failure('Minimum frequency cannot be negative');
    }
    
    if (maxFreq <= minFreq) {
      return ValidationResult.failure('Maximum frequency must be greater than minimum frequency');
    }
    
    if (sampleRate != null) {
      final nyquistFreq = sampleRate / 2;
      if (maxFreq > nyquistFreq) {
        return ValidationResult.failure(
          'Maximum frequency ($maxFreq Hz) exceeds Nyquist frequency ($nyquistFreq Hz)'
        );
      }
    }
    
    // Vocal range validation
    if (minFreq > 10000) {
      return ValidationResult.warning('Minimum frequency seems too high for vocal analysis');
    }
    
    if (maxFreq < 100) {
      return ValidationResult.warning('Maximum frequency seems too low for vocal analysis');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate session name
  ValidationResult validateSessionName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return ValidationResult.failure('Session name cannot be empty');
    }
    
    final trimmedName = name.trim();
    
    if (trimmedName.length < 3) {
      return ValidationResult.failure('Session name must be at least 3 characters long');
    }
    
    if (trimmedName.length > 100) {
      return ValidationResult.failure('Session name must be less than 100 characters');
    }
    
    // Check for invalid characters
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    if (invalidChars.hasMatch(trimmedName)) {
      return ValidationResult.failure('Session name contains invalid characters');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate user ID
  ValidationResult validateUserId(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return ValidationResult.failure('User ID cannot be empty');
    }
    
    final trimmedId = userId.trim();
    
    if (trimmedId.length < 8) {
      return ValidationResult.failure('User ID must be at least 8 characters long');
    }
    
    if (trimmedId.length > 64) {
      return ValidationResult.failure('User ID must be less than 64 characters');
    }
    
    // Check format (alphanumeric and underscores only)
    final validFormat = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validFormat.hasMatch(trimmedId)) {
      return ValidationResult.failure('User ID can only contain letters, numbers, and underscores');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate breathing rate
  ValidationResult validateBreathingRate(double? rate) {
    if (rate == null) {
      return ValidationResult.failure('Breathing rate cannot be null');
    }
    
    if (rate <= 0) {
      return ValidationResult.failure('Breathing rate must be positive');
    }
    
    if (rate < 5) {
      return ValidationResult.warning('Breathing rate seems unusually low (< 5 breaths per minute)');
    }
    
    if (rate > 40) {
      return ValidationResult.warning('Breathing rate seems unusually high (> 40 breaths per minute)');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate pitch value
  ValidationResult validatePitch(double? pitch) {
    if (pitch == null) {
      return ValidationResult.failure('Pitch cannot be null');
    }
    
    if (pitch.isNaN || pitch.isInfinite) {
      return ValidationResult.failure('Pitch cannot be NaN or Infinite');
    }
    
    if (pitch <= 0) {
      return ValidationResult.failure('Pitch must be positive');
    }
    
    // Human vocal range is roughly 80 Hz to 1000 Hz
    if (pitch < 50) {
      return ValidationResult.warning('Pitch seems unusually low for human voice');
    }
    
    if (pitch > 2000) {
      return ValidationResult.warning('Pitch seems unusually high for human voice');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate score (0.0 to 1.0)
  ValidationResult validateScore(double? score) {
    if (score == null) {
      return ValidationResult.failure('Score cannot be null');
    }
    
    if (score.isNaN || score.isInfinite) {
      return ValidationResult.failure('Score cannot be NaN or Infinite');
    }
    
    if (score < 0.0 || score > 1.0) {
      return ValidationResult.failure('Score must be between 0.0 and 1.0');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate duration
  ValidationResult validateDuration(Duration? duration) {
    if (duration == null) {
      return ValidationResult.failure('Duration cannot be null');
    }
    
    if (duration.isNegative) {
      return ValidationResult.failure('Duration cannot be negative');
    }
    
    if (duration.inMilliseconds == 0) {
      return ValidationResult.failure('Duration cannot be zero');
    }
    
    if (duration.inHours > 24) {
      return ValidationResult.warning('Duration seems unusually long (> 24 hours)');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate file path
  ValidationResult validateFilePath(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) {
      return ValidationResult.failure('File path cannot be empty');
    }
    
    final trimmedPath = filePath.trim();
    
    // Check for invalid characters in file path
    final invalidChars = RegExp(r'[<>"|?*]');
    if (invalidChars.hasMatch(trimmedPath)) {
      return ValidationResult.failure('File path contains invalid characters');
    }
    
    // Check path length
    if (trimmedPath.length > 260) {
      return ValidationResult.failure('File path too long (maximum 260 characters)');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate email format
  ValidationResult validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return ValidationResult.failure('Email cannot be empty');
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return ValidationResult.failure('Invalid email format');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate date range
  ValidationResult validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return ValidationResult.failure('Date range cannot have null values');
    }
    
    if (endDate.isBefore(startDate)) {
      return ValidationResult.failure('End date cannot be before start date');
    }
    
    final now = DateTime.now();
    if (startDate.isAfter(now)) {
      return ValidationResult.warning('Start date is in the future');
    }
    
    final daysDifference = endDate.difference(startDate).inDays;
    if (daysDifference > 365) {
      return ValidationResult.warning('Date range spans more than a year');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate collection (list) is not empty
  ValidationResult validateNonEmptyCollection<T>(List<T>? collection, String collectionName) {
    if (collection == null) {
      return ValidationResult.failure('$collectionName cannot be null');
    }
    
    if (collection.isEmpty) {
      return ValidationResult.failure('$collectionName cannot be empty');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate numeric range
  ValidationResult validateNumericRange(num? value, num min, num max, String valueName) {
    if (value == null) {
      return ValidationResult.failure('$valueName cannot be null');
    }
    
    if (value < min || value > max) {
      return ValidationResult.failure('$valueName must be between $min and $max');
    }
    
    return ValidationResult.success();
  }
  
  /// Validate JSON data structure
  ValidationResult validateJsonStructure(Map<String, dynamic>? json, List<String> requiredFields) {
    if (json == null) {
      return ValidationResult.failure('JSON data cannot be null');
    }
    
    if (json.isEmpty) {
      return ValidationResult.failure('JSON data cannot be empty');
    }
    
    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        return ValidationResult.failure('Required field missing: $field');
      }
    }
    
    return ValidationResult.success();
  }
  
  /// Validate model configuration
  ValidationResult validateModelConfig(Map<String, dynamic>? config) {
    if (config == null) {
      return ValidationResult.failure('Model configuration cannot be null');
    }
    
    final requiredFields = ['name', 'version', 'input_shape', 'output_shape'];
    final structureResult = validateJsonStructure(config, requiredFields);
    
    if (!structureResult.isValid) {
      return structureResult;
    }
    
    // Validate specific fields
    final name = config['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return ValidationResult.failure('Model name cannot be empty');
    }
    
    final version = config['version'] as String?;
    if (version == null || version.trim().isEmpty) {
      return ValidationResult.failure('Model version cannot be empty');
    }
    
    return ValidationResult.success();
  }
  
  /// Batch validation for multiple values
  ValidationResult validateBatch(List<ValidationFunction> validations) {
    final errors = <String>[];
    final warnings = <String>[];
    
    for (final validation in validations) {
      final result = validation();
      
      if (!result.isValid) {
        if (result.isWarning) {
          warnings.addAll(result.messages);
        } else {
          errors.addAll(result.messages);
        }
      }
    }
    
    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors.join('; '));
    } else if (warnings.isNotEmpty) {
      return ValidationResult.warning(warnings.join('; '));
    }
    
    return ValidationResult.success();
  }
}

/// Validation result class
class ValidationResult {
  final bool isValid;
  final bool isWarning;
  final List<String> messages;
  
  ValidationResult._({
    required this.isValid,
    required this.isWarning,
    required this.messages,
  });
  
  factory ValidationResult.success() {
    return ValidationResult._(
      isValid: true,
      isWarning: false,
      messages: [],
    );
  }
  
  factory ValidationResult.failure(String message) {
    return ValidationResult._(
      isValid: false,
      isWarning: false,
      messages: [message],
    );
  }
  
  factory ValidationResult.warning(String message) {
    return ValidationResult._(
      isValid: true,
      isWarning: true,
      messages: [message],
    );
  }
  
  /// Get the first error message
  String? get firstError => messages.isNotEmpty ? messages.first : null;
  
  /// Get all messages as a single string
  String get allMessages => messages.join('; ');
  
  @override
  String toString() {
    if (isValid && !isWarning) return 'Valid';
    if (isWarning) return 'Warning: $allMessages';
    return 'Invalid: $allMessages';
  }
}

/// Type definition for validation functions
typedef ValidationFunction = ValidationResult Function();

/// Extension methods for easier validation
extension ValidationExtensions on String? {
  ValidationResult validateAsSessionName() => ValidationUtils().validateSessionName(this);
  ValidationResult validateAsUserId() => ValidationUtils().validateUserId(this);
  ValidationResult validateAsEmail() => ValidationUtils().validateEmail(this);
  ValidationResult validateAsFilePath() => ValidationUtils().validateFilePath(this);
}

extension NumericValidationExtensions on double? {
  ValidationResult validateAsScore() => ValidationUtils().validateScore(this);
  ValidationResult validateAsPitch() => ValidationUtils().validatePitch(this);
  ValidationResult validateAsBreathingRate() => ValidationUtils().validateBreathingRate(this);
}

extension AudioValidationExtensions on List<double>? {
  ValidationResult validateAsAudioData() => ValidationUtils().validateAudioData(this);
}

/// Mixin for classes that need validation
mixin ValidationMixin {
  ValidationResult validate(ValidationFunction validation) {
    try {
      return validation();
    } catch (e, stackTrace) {
      ErrorHandler().handleError(
        ValidationException('Validation error: ${e.toString()}'),
        stackTrace: stackTrace,
        context: 'ValidationMixin.validate',
      );
      return ValidationResult.failure('Validation error occurred');
    }
  }
  
  void validateAndThrow(ValidationFunction validation) {
    final result = validate(validation);
    if (!result.isValid) {
      throw ValidationException(result.allMessages);
    }
  }
  
  bool isValid(ValidationFunction validation) {
    return validate(validation).isValid;
  }
}