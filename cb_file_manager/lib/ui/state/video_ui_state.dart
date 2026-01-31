import 'package:flutter/foundation.dart';

/// Global UI flags related to video playback.
class VideoUiState {
  // Indicates whether a video player is currently in fullscreen mode on mobile.
  static final ValueNotifier<bool> isFullscreen = ValueNotifier<bool>(false);

  // Tracks whether at least one video player is currently active (mounted).
  // This is used to suppress expensive background work (e.g., network thumbnail extraction)
  // while video playback is in progress.
  static final ValueNotifier<bool> isPlayerActive = ValueNotifier<bool>(false);

  static int _activePlayers = 0;

  static void notifyPlayerMounted() {
    _activePlayers += 1;
    if (!isPlayerActive.value) {
      isPlayerActive.value = true;
    }
  }

  static void notifyPlayerDisposed() {
    _activePlayers -= 1;
    if (_activePlayers < 0) _activePlayers = 0;
    if (_activePlayers == 0 && isPlayerActive.value) {
      isPlayerActive.value = false;
    }
  }
}
