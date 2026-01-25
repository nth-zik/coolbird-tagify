import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as pathlib;

import 'package:cb_file_manager/ui/components/video/video_player/video_info_dialog.dart';
import 'package:cb_file_manager/ui/components/video/video_player/video_player.dart';
import 'package:cb_file_manager/ui/components/video/video_player/video_player_app_bar.dart';

class VideoPlayerFullScreen extends StatefulWidget {
  /// Local file (use when path is available, e.g. file:// on Android).
  final File? file;
  /// Android content:// URI when opened via "Open with" / default app.
  final String? contentUri;

  VideoPlayerFullScreen({
    Key? key,
    this.file,
    this.contentUri,
  }) : assert(file != null || (contentUri != null && contentUri.isNotEmpty)),
       super(key: key);

  @override
  _VideoPlayerFullScreenState createState() => _VideoPlayerFullScreenState();
}

String _shortName(String? contentUri) {
  if (contentUri == null || contentUri.isEmpty) return 'Video';
  final u = contentUri.split('/').last;
  return u.isNotEmpty ? u : 'Video';
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
                  title: widget.file != null
                      ? pathlib.basename(widget.file!.path)
                      : _shortName(widget.contentUri),
                  actions: [
                    if (widget.file != null)
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
        child: _buildPlayer(context),
      ),
    );
    return isMobile
        ? AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light, child: scaffold)
        : scaffold;
  }

  Widget _buildPlayer(BuildContext context) {
    final onInit = (Map<String, dynamic> metadata) {
      setState(() => _videoMetadata = metadata);
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      }
    };
    final onErr = (String errorMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('L?i: $errorMessage')),
      );
    };
    final onFs = () {
      setState(() {
        _isFullScreen = !_isFullScreen;
        _showAppBar = true;
        if (_isFullScreen) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _isFullScreen) setState(() => _showAppBar = false);
          });
        }
      });
    };
    final onCtrl = () {
      if (_isFullScreen) {
        setState(() => _showAppBar = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isFullScreen) setState(() => _showAppBar = false);
        });
      }
    };
    if (widget.file != null) {
      return VideoPlayer.file(
        file: widget.file!,
        autoPlay: true,
        showControls: true,
        allowFullScreen: true,
        onVideoInitialized: onInit,
        onError: onErr,
        onFullScreenChanged: onFs,
        onControlVisibilityChanged: onCtrl,
        onOpenFolder: (folderPath, highlightedFileName) {
          Navigator.of(context).pop({
            'action': 'openFolder',
            'folderPath': folderPath,
            'highlightedFileName': highlightedFileName,
          });
        },
      );
    }
    return VideoPlayer.url(
      streamingUrl: widget.contentUri!,
      fileName: _shortName(widget.contentUri),
      autoPlay: true,
      showControls: true,
      allowFullScreen: true,
      onVideoInitialized: onInit,
      onError: onErr,
      onFullScreenChanged: onFs,
      onControlVisibilityChanged: onCtrl,
    );
  }

  void _showVideoInfo(BuildContext context) {
    if (widget.file == null) return;
    showDialog(
      context: context,
      builder: (context) => VideoInfoDialog(
        file: widget.file!,
        videoMetadata: _videoMetadata,
      ),
    );
  }
}
