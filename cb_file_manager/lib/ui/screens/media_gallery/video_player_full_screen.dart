import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as pathlib;

import 'package:cb_file_manager/ui/components/video/video_player/video_player.dart';
import 'package:cb_file_manager/ui/components/video/video_player/video_player_app_bar.dart';

class VideoPlayerFullScreen extends StatefulWidget {
  final File file;

  const VideoPlayerFullScreen({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  _VideoPlayerFullScreenState createState() => _VideoPlayerFullScreenState();
}

class _VideoPlayerFullScreenState extends State<VideoPlayerFullScreen> {
  Map<String, dynamic>? _videoMetadata;
  bool _isFullScreen = false;
  bool _showAppBar = true; // Control app bar visibility
  bool _inAndroidPip = false;
  Timer? _uiEnforceTimer;

  @override
  void initState() {
    super.initState();
    // On mobile, show full UI (both status bar and nav bar)
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      // Also force style after first frame to avoid being overridden
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      });
      // Ensure Flutter re-applies overlays automatically while this route is on top
      WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = true;
      // Re-assert overlays for a short period in case platform view toggles them off
      int attempts = 0;
      _uiEnforceTimer?.cancel();
      _uiEnforceTimer =
          Timer.periodic(const Duration(milliseconds: 400), (t) async {
        attempts++;
        if (!mounted || _isFullScreen || attempts > 10) {
          t.cancel();
          return;
        }
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      });
    }
    // Hide app bar while in Android PiP so PiP captures only the video
    const channel = MethodChannel('cb_file_manager/pip');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        final args = call.arguments;
        bool inPip = false;
        if (args is Map) {
          inPip = args['inPip'] == true;
        }
        if (mounted) {
          setState(() => _inAndroidPip = inPip);
        }
      }
    });
  }

  @override
  void dispose() {
    // Restore system UI when leaving video player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    // Keep automatic adjustment enabled for underlying screens
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = true;
    _uiEnforceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    final scaffold = Scaffold(
      // On mobile, avoid extra app bar since parent already has one
      appBar: isMobile
          ? null
          : ((_isFullScreen && !_showAppBar) || _inAndroidPip
              ? null // Hide app bar completely when in fullscreen and _showAppBar is false
              : VideoPlayerAppBar(
                  title: pathlib.basename(widget.file.path),
                  actions: [
                    IconButton(
                      icon:
                          const Icon(Icons.info_outline, color: Colors.white70),
                      onPressed: () => _showVideoInfo(context),
                    ),
                  ],
                  onClose: () {
                    // Close the app completely when close button is pressed
                    exit(0);
                  },
                  showWindowControls: true,
                  blurAmount: 12.0,
                  opacity: 0.6,
                )),
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Center(
        child: VideoPlayer.file(
          file: widget.file,
          autoPlay: true,
          showControls: true,
          allowFullScreen: true,
          onVideoInitialized: (metadata) {
            setState(() {
              _videoMetadata = metadata;
            });
            // Ensure status bar is visible after player initializes (some plugins toggle UI)
            if (Platform.isAndroid || Platform.isIOS) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                  overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
            }
          },
          onError: (errorMessage) {
            // Optional: Show a snackbar or other notification
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('L?i: $errorMessage')),
            );
          },
          // Add callbacks to synchronize fullscreen state and control visibility
          onFullScreenChanged: () {
            setState(() {
              _isFullScreen = !_isFullScreen;
              // When entering fullscreen, start with controls/appbar visible then hide after delay
              _showAppBar = true;
              if (_isFullScreen) {
                // Auto-hide after a delay
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _isFullScreen) {
                    setState(() {
                      _showAppBar = false;
                    });
                  }
                });
              }
            });
          },
          onControlVisibilityChanged: () {
            // Sync app bar visibility with video controls visibility
            if (_isFullScreen) {
              setState(() {
                _showAppBar = true;
              });
              // Auto-hide after a delay
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _isFullScreen) {
                  setState(() {
                    _showAppBar = false;
                  });
                }
              });
            }
          },
          onOpenFolder: (folderPath, highlightedFileName) {
            debugPrint(
                '========== VIDEO_GALLERY onOpenFolder CALLBACK ==========');
            debugPrint('Folder path: $folderPath');
            debugPrint('Highlighted file: $highlightedFileName');

            // Pop back to parent screen with result containing folder info
            // The parent (tabbed_folder_list_screen) will handle opening the tab
            Navigator.of(context).pop({
              'action': 'openFolder',
              'folderPath': folderPath,
              'highlightedFileName': highlightedFileName,
            });

            debugPrint('Popped with folder open request');
            debugPrint('========== END VIDEO_GALLERY onOpenFolder ==========');
          },
        ),
      ),
    );
    return isMobile
        ? AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light, child: scaffold)
        : scaffold;
  }

  void _showVideoInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => VideoInfoDialog(
        file: widget.file,
        videoMetadata: _videoMetadata,
      ),
    );
  }
}
