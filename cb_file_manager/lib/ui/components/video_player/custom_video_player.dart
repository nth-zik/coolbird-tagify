import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as pathlib;
import 'package:window_manager/window_manager.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
// Windows audio fix imports
import 'package:cb_file_manager/ui/components/video_player/windows_audio_fix.dart';

// Media Kit imports - replacing standard video_player
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomVideoPlayer extends StatefulWidget {
  final File file;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final bool allowFullScreen;
  final bool allowMuting;
  final bool allowPlaybackSpeedChanging;
  final Function(Map<String, dynamic>)? onVideoInitialized;
  final Function(String)? onError;
  final VoidCallback? onNextVideo;
  final VoidCallback? onPreviousVideo;
  final bool hasNextVideo;
  final bool hasPreviousVideo;

  const CustomVideoPlayer({
    Key? key,
    required this.file,
    this.autoPlay = true,
    this.looping = false,
    this.showControls = true,
    this.allowFullScreen = true,
    this.allowMuting = true,
    this.allowPlaybackSpeedChanging = true,
    this.onVideoInitialized,
    this.onError,
    this.onNextVideo,
    this.onPreviousVideo,
    this.hasNextVideo = false,
    this.hasPreviousVideo = false,
  }) : super(key: key);

  @override
  _CustomVideoPlayerState createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  // Media Kit controllers
  late final Player _player;
  late final VideoController _videoController;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isFullScreen = false;
  bool _isPlaying = false; // Local state variable to track playing state
  bool _isMuted = false; // Local state variable to track mute state
  String _errorMessage = '';
  Timer? _initializationTimeout;
  Map<String, dynamic>? _videoMetadata;
  double _savedVolume = 70.0; // Store volume as 0.0-100.0 scale, default 70.0
  bool _showAudioTracksMenu = false; // Track if audio tracks menu is open

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(CustomVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _disposeControllers();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      // Set a timeout for initialization
      _initializationTimeout = Timer(const Duration(seconds: 30), () {
        if (_isLoading && mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Video initialization timed out after 30 seconds';
          });

          if (widget.onError != null) {
            widget.onError!(_errorMessage);
          }
        }
      });

      // Load saved volume and mute preferences before creating player
      final userPreferences = UserPreferences();
      await userPreferences.init();

      // Load volume as 0.0-100.0
      _savedVolume = userPreferences.getVideoPlayerVolume();
      // Ensure volume is within valid range
      if (_savedVolume < 0.0 || _savedVolume > 100.0) {
        _savedVolume = 70.0;
      }
      _isMuted = userPreferences.getVideoPlayerMute();
      debugPrint(
          'Loaded preferences - volume: ${_savedVolume.toStringAsFixed(1)}, muted: $_isMuted');

      // Create Media Kit player instance
      _player = Player();

      // Apply audio settings before creating video controller
      // await MediaKitAudioHelper.configurePlayerAudio(_player);

      // Create video controller after audio setup
      _videoController = VideoController(_player);

      // Add error listener
      _player.stream.error.listen((error) {
        debugPrint('Player error: $error');
        if (mounted && !_hasError) {
          setState(() {
            _hasError = true;
            _errorMessage = error;
          });
          if (widget.onError != null) {
            widget.onError!(_errorMessage);
          }
        }
      });

      // Add more detailed logging for debugging audio issues
      _player.stream.log.listen((event) {
        final logStr = event.toString();
        if (logStr.contains('audio') ||
            logStr.contains('sound') ||
            logStr.contains('volume')) {
          debugPrint('Player log: $logStr');
        }
      });

      // Determine volume to apply based on mute state (0.0-100.0)
      final volumeToApply = _isMuted ? 0.0 : _savedVolume;
      debugPrint(
          'Will apply volume: ${volumeToApply.toStringAsFixed(1)} (muted: $_isMuted)');

      // Initialize with smart audio options
      await _initializeWithSmartAudioOptions(volumeToApply);

      // Set initial playing state and ensure UI reflects this correctly
      if (widget.autoPlay) {
        await _player.play();
        if (mounted) {
          setState(() {
            _isPlaying = true; // Update local state to ensure UI is correct
          });
        }
      }

      // Track changes in playing state from the player
      _player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
          });
        }
      });

      // Track changes in volume from the player (MediaKit uses 0.0-100.0 in our implementation)
      _player.stream.volume.listen((volume) {
        // Volume is now directly 0.0-100.0
        debugPrint('Volume changed to: ${volume.toStringAsFixed(1)}');

        // Update mute state based on volume
        final wasMuted = _isMuted;
        final isMutedNow = volume <= 0.1; // Use a small threshold as "muted"

        if (wasMuted != isMutedNow) {
          setState(() {
            _isMuted = isMutedNow;
          });

          // Save mute state when it changes
          userPreferences.setVideoPlayerMute(isMutedNow);
          debugPrint('Saved mute state: $isMutedNow');
        }

        // Only update volume preference if not muted and volume changed significantly
        if (!isMutedNow && (_savedVolume - volume).abs() > 0.5) {
          setState(() {
            _savedVolume = volume;
          });
          userPreferences.setVideoPlayerVolume(volume);
          debugPrint('Saved volume preference: ${volume.toStringAsFixed(1)}');
        }
      });

      // Wait for video info to be available
      await Future.delayed(const Duration(milliseconds: 300));

      // Cancel timeout as we've successfully initialized
      _initializationTimeout?.cancel();
      _initializationTimeout = null;

      // Extract video metadata for information display
      _videoMetadata = {
        'duration': _player.state.duration,
        'width': _player.state.width,
        'height': _player.state.height,
      };

      // Notify parent widget that initialization is complete
      if (widget.onVideoInitialized != null) {
        widget.onVideoInitialized!(_videoMetadata!);
      }

      // Update UI with loaded video
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Cancel timeout if there was an error
      _initializationTimeout?.cancel();
      _initializationTimeout = null;

      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });

        if (widget.onError != null) {
          widget.onError!(_errorMessage);
        }
      }
    }
  }

  /// Initialize with default audio options - volume is 0.0-100.0
  Future<void> _initializeWithSmartAudioOptions(double volumeValue) async {
    debugPrint(
        'Opening media file with default audio settings: ${widget.file.path}');

    // Open media with default settings
    await _player.open(
      Media(widget.file.path),
      play: false,
    );

    // Give time for audio subsystem to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    // Ensure audio track is selected
    await _player.setAudioTrack(AudioTrack.auto());

    // Set volume in the range of 0.0 to 100.0
    await _player.setVolume(volumeValue.clamp(0.0, 100.0));

    debugPrint('Applied volume: ${volumeValue.toStringAsFixed(1)}');
  }

  Widget _buildErrorWidget([String? errorMessage]) {
    final message = errorMessage ?? _errorMessage;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Không thể phát video này\n\n$message',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _disposeControllers();
              _initializePlayer();
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  void _disposeControllers() {
    _initializationTimeout?.cancel();
    _player.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // Toggle fullscreen state
  Future<void> _toggleFullScreen() async {
    if (widget.allowFullScreen) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop platforms - use window_manager
        try {
          bool isFullScreen = await windowManager.isFullScreen();
          if (isFullScreen) {
            // Exit fullscreen mode
            await windowManager.setFullScreen(false);
            await windowManager.setResizable(true);
          } else {
            // Enter fullscreen mode
            await windowManager.setFullScreen(true);
          }
          setState(() {
            _isFullScreen = !isFullScreen;
          });
        } catch (e) {
          debugPrint('Error toggling fullscreen: $e');
        }
      } else {
        // Mobile platforms - use system chrome
        setState(() {
          _isFullScreen = !_isFullScreen;
        });

        if (_isFullScreen) {
          // Enter fullscreen mode
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          // Exit fullscreen mode
          SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
        : _hasError
            ? _buildErrorWidget()
            : Stack(
                children: [
                  // Base video with double-click for fullscreen
                  GestureDetector(
                    onDoubleTap:
                        widget.allowFullScreen ? _toggleFullScreen : null,
                    child: ClipRRect(
                      borderRadius: _isFullScreen
                          ? BorderRadius.zero
                          : BorderRadius.circular(8.0),
                      child: Video(
                        controller: _videoController,
                        controls: null, // Always use our custom controls
                        fill: Colors.black,
                      ),
                    ),
                  ),

                  // Add custom controls if enabled
                  if (widget.showControls) _buildCustomControls(),
                ],
              );
  }

  // Build the complete set of custom controls
  Widget _buildCustomControls() {
    return Stack(
      children: [
        // Bottom control bar with seekbar, play/pause, next/prev, and volume
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom seek bar
              _buildCustomSeekBar(),

              // Main controls row with attractive UI
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Previous button
                    _buildControlButton(
                      icon: Icons.skip_previous,
                      onPressed: widget.hasPreviousVideo &&
                              widget.onPreviousVideo != null
                          ? widget.onPreviousVideo
                          : null,
                      enabled: widget.hasPreviousVideo,
                    ),

                    // Play/Pause button with larger size
                    StreamBuilder<bool>(
                      stream: _player.stream.playing,
                      initialData:
                          _isPlaying, // Use local state for initial value
                      builder: (context, snapshot) {
                        // Use local state variable when stream doesn't have data yet
                        final isPlaying = snapshot.data ?? _isPlaying;

                        return _buildControlButton(
                          icon: isPlaying ? Icons.pause : Icons.play_arrow,
                          onPressed: _togglePlayPause,
                          size: 36,
                          padding: 12,
                          enabled: true,
                        );
                      },
                    ),

                    // Next button
                    _buildControlButton(
                      icon: Icons.skip_next,
                      onPressed:
                          widget.hasNextVideo && widget.onNextVideo != null
                              ? widget.onNextVideo
                              : null,
                      enabled: widget.hasNextVideo,
                    ),

                    // Flexible spacer to push volume and fullscreen to the right
                    const Spacer(),

                    // Volume control
                    if (widget.allowMuting) _buildVolumeControl(),

                    // Windows Audio Fix Button for audio troubleshooting
                    if (Platform.isWindows)
                      WindowsAudioFixButton(
                        onAudioConfigSelected: (audioConfig) {
                          debugPrint('Applying new audio config: $audioConfig');
                          // Reopen the media with the new audio configuration
                          _player.open(
                            Media(
                              widget.file.path,
                              extras: audioConfig,
                            ),
                            play: _isPlaying,
                          );
                        },
                      ),

                    // Audio track selection button
                    _buildAudioTrackButton(),

                    // Fullscreen button
                    if (widget.allowFullScreen)
                      _buildControlButton(
                        icon: _isFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        onPressed: _toggleFullScreen,
                        enabled: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Common method to create control buttons with consistent styling and cursor behavior
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 28,
    double padding = 8,
    bool enabled = true,
    String? tooltip,
  }) {
    return MouseRegion(
      cursor: onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(50),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Tooltip(
              message: tooltip ?? '',
              child: Icon(
                icon,
                color: enabled ? Colors.white : Colors.white.withOpacity(0.4),
                size: size,
                semanticLabel: icon.codePoint.toString(), // For accessibility
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build the volume control with slider
  Widget _buildVolumeControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Volume button that toggles mute
        StreamBuilder<double>(
            stream: _player.stream.volume,
            initialData: _isMuted ? 0.0 : _savedVolume,
            builder: (context, snapshot) {
              final currentVolume = snapshot.data ?? 0.0; // 0.0-100.0 scale

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () async {
                      final userPreferences = UserPreferences();
                      await userPreferences.init();

                      // Toggle mute state
                      final newMuteState = !_isMuted;

                      setState(() {
                        _isMuted = newMuteState;
                      });

                      if (newMuteState) {
                        // Set volume to 0 (mute)
                        await _player.setVolume(0.0);
                        await userPreferences.setVideoPlayerMute(true);
                        debugPrint('Muted and saved state');
                      } else {
                        // Unmute - restore saved volume
                        final volumeToRestore =
                            _savedVolume > 0.1 ? _savedVolume : 70.0;
                        await _player.setVolume(volumeToRestore);
                        await userPreferences.setVideoPlayerMute(false);
                        debugPrint(
                            'Unmuted with volume: ${volumeToRestore.toStringAsFixed(1)}');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        currentVolume <= 0.1
                            ? Icons.volume_off
                            : currentVolume < 50.0
                                ? Icons.volume_down
                                : Icons.volume_up,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              );
            }),

        // Volume slider using 0.0-100.0 scale
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: 100,
            child: StreamBuilder<double>(
              stream: _player.stream.volume,
              initialData: _isMuted ? 0.0 : _savedVolume,
              builder: (context, snapshot) {
                final currentVolume = snapshot.data ?? 0.0; // Already 0.0-100.0

                return SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withOpacity(0.3),
                  ),
                  child: Slider(
                    value: currentVolume.clamp(0.0, 100.0),
                    min: 0.0,
                    max: 100.0,
                    onChanged: (value) async {
                      // Ensure the value is clamped between 0.0 and 100.0
                      final clampedValue = value.clamp(0.0, 100.0);

                      // Set volume directly in the range of 0.0 to 100.0
                      await _player.setVolume(clampedValue);

                      // Update mute state based on volume
                      final newMuteState = clampedValue <= 0.1;
                      if (_isMuted != newMuteState) {
                        setState(() {
                          _isMuted = newMuteState;
                        });

                        // Save new mute state
                        final userPreferences = UserPreferences();
                        await userPreferences.init();
                        await userPreferences.setVideoPlayerMute(newMuteState);
                      }

                      // If not muted, save the new volume preference
                      if (!newMuteState) {
                        setState(() {
                          _savedVolume = clampedValue;
                        });

                        // Save to preferences
                        final userPreferences = UserPreferences();
                        await userPreferences.init();
                        await userPreferences
                            .setVideoPlayerVolume(clampedValue);
                        debugPrint(
                            'Volume slider changed to: ${clampedValue.toStringAsFixed(1)}');
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Build a custom seek bar that's much bigger than default
  Widget _buildCustomSeekBar() {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.state.duration;

        // Calculate progress value (0.0 to 1.0)
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 50, // Reduced height to bring it closer to controls
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.only(
              bottom: 0, // Removed bottom padding to move closer to controls
              left: 16,
              right: 16,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // Make the entire area tappable
              onTapDown: (details) {
                _handleSeekGesture(details.localPosition.dx, context);
              },
              onHorizontalDragUpdate: (details) {
                _handleSeekGesture(details.localPosition.dx, context);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end, // Align to bottom
                children: [
                  // Actual visible seek bar
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Background track
                      Container(
                        height: 16, // Much thicker than default
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withOpacity(0.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),

                      // Played portion
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [Colors.redAccent, Colors.red],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Thumb/handle
                      Positioned(
                        left: (MediaQuery.of(context).size.width - 32) *
                                progress.clamp(0.0, 1.0) -
                            8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Time indicators
                  const SizedBox(height: 5), // Reduced spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 2,
                                color: Color.fromARGB(150, 0, 0, 0),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 2,
                                color: Color.fromARGB(150, 0, 0, 0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Handle seek gestures
  void _handleSeekGesture(double dx, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;

    // Calculate position percentage based on touch position
    final seekPosition = dx.clamp(0.0, width) / width;

    // Convert to milliseconds and seek
    final seekMs =
        (_player.state.duration.inMilliseconds * seekPosition).round();
    _player.seek(Duration(milliseconds: seekMs));
  }

  // Toggle play/pause state
  void _togglePlayPause() async {
    // Update local state immediately for UI responsiveness
    setState(() {
      _isPlaying = !_player.state.playing;
    });

    // Then update the actual player state
    if (_player.state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }

    // Force another update to ensure UI is in sync with player
    if (mounted) {
      setState(() {});
    }
  }

  // Helper methods for video information
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  // Build audio track selection button
  Widget _buildAudioTrackButton() {
    return StreamBuilder<Tracks>(
      stream: _player.stream.tracks,
      builder: (context, snapshot) {
        final tracks = snapshot.data;
        final audioTracks = tracks?.audio ?? [];

        // Log detailed information about audio tracks
        debugPrint('Audio tracks available: ${audioTracks.length}');
        for (int i = 0; i < audioTracks.length; i++) {
          final track = audioTracks[i];
          debugPrint('Audio track $i: id=${track.id}, title=${track.title}, '
              'language=${track.language}, codec=${track.codec}');
        }

        // Log current selected track
        final currentTrack = _player.state.track.audio;
        debugPrint('Current audio track: ${currentTrack?.id ?? "none"}');

        if (audioTracks.isEmpty) {
          debugPrint('No audio tracks available, hiding audio track button');
          return const SizedBox.shrink();
        }

        return PopupMenuButton<int>(
          icon: const Icon(Icons.audiotrack, color: Colors.white),
          onSelected: (index) async {
            debugPrint('Selecting audio track: ${audioTracks[index].id}');
            await _player.setAudioTrack(audioTracks[index]);
          },
          itemBuilder: (context) {
            return List.generate(audioTracks.length, (index) {
              final track = audioTracks[index];
              final isSelected = track.id == _player.state.track.audio?.id;
              return PopupMenuItem<int>(
                value: index,
                child: Row(
                  children: [
                    if (isSelected)
                      const Icon(Icons.check, size: 16, color: Colors.green)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(track.title ?? 'Audio Track ${index + 1}'),
                  ],
                ),
              );
            });
          },
        );
      },
    );
  }
}

// A component that displays video information
class VideoInfoDialog extends StatelessWidget {
  final File file;
  final Map<String, dynamic>? videoMetadata;

  const VideoInfoDialog({
    Key? key,
    required this.file,
    this.videoMetadata,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FileStat>(
      future: file.stat(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AlertDialog(
            title: Text('Thông tin video'),
            content: Center(child: CircularProgressIndicator()),
          );
        }

        final fileStat = snapshot.data!;
        final fileSize = _formatFileSize(fileStat.size);
        final modified = fileStat.modified;

        return AlertDialog(
          title: const Text('Thông tin video'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('Tên tập tin', pathlib.basename(file.path)),
                const Divider(),
                _infoRow('Đường dẫn', file.path),
                const Divider(),
                _infoRow('Kích thước', fileSize),
                const Divider(),
                _infoRow(
                    'Loại tệp', pathlib.extension(file.path).toUpperCase()),
                const Divider(),
                _infoRow('Cập nhật lần cuối',
                    '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute}'),
                if (videoMetadata != null) ...[
                  const Divider(),
                  _infoRow('Độ dài',
                      _formatDuration(videoMetadata!['duration'] as Duration)),
                  const Divider(),
                  _infoRow('Độ phân giải',
                      '${videoMetadata!['width']} x ${videoMetadata!['height']}'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
