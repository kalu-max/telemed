import 'package:flutter/foundation.dart';
import 'network_controller.dart';

enum VideoResolution { p360, p480, p720, p1080 }

enum VideoFrameRate { fps15, fps24, fps30 }

class VideoSettings {
  final VideoResolution resolution;
  final VideoFrameRate frameRate;
  final int bitrate; // in kbps
  final int maxBitrate;
  final int minBitrate;

  VideoSettings({
    required this.resolution,
    required this.frameRate,
    required this.bitrate,
    required this.maxBitrate,
    required this.minBitrate,
  });

  @override
  String toString() {
    String resStr = _resolutionToString(resolution);
    String fpsStr = _fpsToString(frameRate);
    return '$resStr @ $fpsStr ($bitrate kbps)';
  }

  static String _resolutionToString(VideoResolution res) {
    switch (res) {
      case VideoResolution.p360:
        return '360p';
      case VideoResolution.p480:
        return '480p';
      case VideoResolution.p720:
        return '720p';
      case VideoResolution.p1080:
        return '1080p';
    }
  }

  static String _fpsToString(VideoFrameRate fps) {
    switch (fps) {
      case VideoFrameRate.fps15:
        return '15fps';
      case VideoFrameRate.fps24:
        return '24fps';
      case VideoFrameRate.fps30:
        return '30fps';
    }
  }
}

class AdaptiveBitrateController extends ChangeNotifier {
  late VideoSettings _currentSettings;
  late MultiNetworkController _networkController;
  
  // Preset configurations for different scenarios
  static const Map<VideoResolution, Map<VideoFrameRate, int>> bitratePresets = {
    // Resolution -> FrameRate -> Bitrate (kbps)
    VideoResolution.p360: {
      VideoFrameRate.fps15: 250,
      VideoFrameRate.fps24: 400,
      VideoFrameRate.fps30: 500,
    },
    VideoResolution.p480: {
      VideoFrameRate.fps15: 500,
      VideoFrameRate.fps24: 800,
      VideoFrameRate.fps30: 1200,
    },
    VideoResolution.p720: {
      VideoFrameRate.fps15: 1000,
      VideoFrameRate.fps24: 1500,
      VideoFrameRate.fps30: 2500,
    },
    VideoResolution.p1080: {
      VideoFrameRate.fps15: 1500,
      VideoFrameRate.fps24: 2500,
      VideoFrameRate.fps30: 4500,
    },
  };

  AdaptiveBitrateController({required MultiNetworkController networkController}) {
    _networkController = networkController;
    _currentSettings = _getDefaultVideoSettings();
    _networkController.addListener(_onNetworkChanged);
  }

  VideoSettings get currentSettings => _currentSettings;

  void _onNetworkChanged() {
    _adjustVideoQuality();
  }

  void _adjustVideoQuality() {
    final networkInfo = _networkController.currentNetwork;
    if (networkInfo == null) return;

    final newSettings = _selectOptimalSettings(networkInfo);
    
    if (newSettings.resolution != _currentSettings.resolution ||
        newSettings.frameRate != _currentSettings.frameRate) {
      _currentSettings = newSettings;
      notifyListeners();
    }
  }

  VideoSettings _selectOptimalSettings(NetworkInfo networkInfo) {
    final availableBandwidth = networkInfo.bandwidth;

    // Select resolution and frame rate based on available bandwidth
    // Leave 30% headroom for overhead and fluctuations
    final usableBandwidth = availableBandwidth * 0.7;

    if (usableBandwidth >= 3.5) {
      // 3.5+ Mbps: Full HD
      return _createVideoSettings(VideoResolution.p1080, VideoFrameRate.fps30);
    } else if (usableBandwidth >= 2.0) {
      // 2-3.5 Mbps: HD
      return _createVideoSettings(VideoResolution.p720, VideoFrameRate.fps30);
    } else if (usableBandwidth >= 1.2) {
      // 1.2-2 Mbps: Standard Definition
      return _createVideoSettings(VideoResolution.p480, VideoFrameRate.fps24);
    } else if (usableBandwidth >= 0.6) {
      // 0.6-1.2 Mbps: Low resolution
      return _createVideoSettings(VideoResolution.p360, VideoFrameRate.fps15);
    } else {
      // < 0.6 Mbps: Minimum quality (audio focus)
      return _createVideoSettings(VideoResolution.p360, VideoFrameRate.fps15);
    }
  }

  VideoSettings _createVideoSettings(
    VideoResolution resolution,
    VideoFrameRate frameRate,
  ) {
    final bitrate = bitratePresets[resolution]![frameRate]!;
    return VideoSettings(
      resolution: resolution,
      frameRate: frameRate,
      bitrate: bitrate,
      maxBitrate: (bitrate * 1.3).toInt(), // 30% headroom
      minBitrate: (bitrate * 0.7).toInt(), // 70% floor
    );
  }

  VideoSettings _getDefaultVideoSettings() {
    // Start with conservative settings
    return _createVideoSettings(VideoResolution.p480, VideoFrameRate.fps24);
  }

  // Manual quality adjustment (user preference override)
  void setVideoQuality(VideoResolution resolution, VideoFrameRate frameRate) {
    _currentSettings = _createVideoSettings(resolution, frameRate);
    notifyListeners();
  }

  // Get recommended quality based on specific use case
  VideoSettings getRecommendedQuality({
    bool screenShare = false,
    bool isLowBattery = false,
  }) {
    final networkInfo = _networkController.currentNetwork;
    if (networkInfo == null) return _getDefaultVideoSettings();

    // Screen sharing requires less bandwidth than video
    final bandwidthAdjustment = screenShare ? 1.2 : 1.0;
    final adjustedBandwidth = networkInfo.bandwidth / bandwidthAdjustment;

    if (adjustedBandwidth >= 3.5) {
      return _createVideoSettings(VideoResolution.p1080, VideoFrameRate.fps30);
    } else if (adjustedBandwidth >= 2.0) {
      return _createVideoSettings(VideoResolution.p720, VideoFrameRate.fps30);
    } else if (adjustedBandwidth >= 1.2) {
      return _createVideoSettings(VideoResolution.p480, VideoFrameRate.fps24);
    } else {
      return _createVideoSettings(VideoResolution.p360, VideoFrameRate.fps15);
    }
  }

  // Get all available quality options
  List<VideoSettings> getAvailableQualityOptions() {
    return [
      _createVideoSettings(VideoResolution.p1080, VideoFrameRate.fps30),
      _createVideoSettings(VideoResolution.p1080, VideoFrameRate.fps24),
      _createVideoSettings(VideoResolution.p720, VideoFrameRate.fps30),
      _createVideoSettings(VideoResolution.p480, VideoFrameRate.fps30),
      _createVideoSettings(VideoResolution.p360, VideoFrameRate.fps15),
    ];
  }

  // Estimate required bandwidth for quality
  double getRequiredBandwidth(VideoResolution resolution, VideoFrameRate frameRate) {
    final bitrate = bitratePresets[resolution]?[frameRate] ?? 500;
    return bitrate / 1000; // Convert kbps to Mbps
  }

  @override
  void dispose() {
    _networkController.removeListener(_onNetworkChanged);
    super.dispose();
  }
}
