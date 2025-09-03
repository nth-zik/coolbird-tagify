import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopPipWindow extends StatefulWidget {
  final Map<String, dynamic> args;
  const DesktopPipWindow({Key? key, required this.args}) : super(key: key);

  @override
  State<DesktopPipWindow> createState() => _DesktopPipWindowState();
}

class _DesktopPipWindowState extends State<DesktopPipWindow>
    with WindowListener {
  Player? _player;
  VideoController? _controller;
  bool _isPlaying = true;
  Timer? _saveDebounce;
  StreamSubscription<int?>? _videoWSub;
  StreamSubscription<int?>? _videoHSub;
  int? _videoW;
  int? _videoH;
  bool _initialAspectApplied = false;

  // Overlay controls
  bool _showOverlay = true;
  Timer? _overlayHideTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _seeking = false;
  int? _pendingInitialSeekMs;
  bool _initialSyncApplied = false;

  // IPC back to main window
  Socket? _ipc;
  String? _ipcToken;
  int? _ipcPort;

  @override
  void initState() {
    super.initState();
    _initWindow();
    _initPlayer();
    _initIpc();
  }

  Future<void> _initWindow() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    // Restore last PiP size if available; otherwise use a comfortable default.
    final prefs = await SharedPreferences.getInstance();
    final savedW = prefs.getDouble('pip_w');
    final savedH = prefs.getDouble('pip_h');

    const Size defaultSize = Size(384, 216); // 16:9, reasonably sized
    const Size minSize = Size(240, 135); // 16:9, small but usable
    final Size initialSize = (savedW != null && savedH != null &&
            savedW >= minSize.width && savedH >= minSize.height)
        ? Size(savedW, savedH)
        : defaultSize;

    final options = WindowOptions(
      size: initialSize,
      minimumSize: minSize,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options);
    // Enforce aspect ratio during resize so PiP keeps its proportions.
    try {
      final aspect = initialSize.width / initialSize.height;
      await windowManager.setAspectRatio(aspect);
    } catch (_) {
      // If not supported on a platform/version, just continue without it.
    }
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();

    final title = (widget.args['fileName'] as String?) ?? 'PiP';
    // setTitle is safe even with hidden title bar
    await windowManager.setTitle('PiP - $title');
  }

  Future<void> _initPlayer() async {
    MediaKit.ensureInitialized();
    _player = Player();
    _controller = VideoController(_player!);

    final type = (widget.args['sourceType'] as String?) ?? 'url';
    final src = (widget.args['source'] as String?) ?? '';
    final positionMs = (widget.args['positionMs'] as int?) ?? 0;
    final initialVolume = (widget.args['volume'] as num?)?.toDouble();
    final shouldPlay = widget.args['playing'] == null
        ? true
        : (widget.args['playing'] == true);

    String openSrc = src;
    if (type == 'smb' && Platform.isWindows) {
      openSrc = _normalizeToFileUri(_smbToUnc(src));
    }

    await _player!.open(Media(openSrc));
    // Ensure stable state before applying initial seek & volume
    try {
      await _player!.pause();
    } catch (_) {}
    // Wait briefly until player reports a valid duration (if available)
    await _waitForReady();
    // Listen for video dimension updates to keep window aspect ratio in sync.
    _videoWSub = _player!.stream.width.listen((w) {
      _videoW = w;
      _maybeApplyVideoAspectRatio();
    });
    _videoHSub = _player!.stream.height.listen((h) {
      _videoH = h;
      _maybeApplyVideoAspectRatio();
    });
    // Listen for playback position & duration for seekbar updates.
    _posSub = _player!.stream.position.listen((p) {
      if (!_seeking) {
        setState(() => _position = p);
      }
    });
    _durSub = _player!.stream.duration.listen((d) {
      setState(() => _duration = d);
      _tryApplyInitialSeek();
    });
    _pendingInitialSeekMs = positionMs > 0 ? positionMs : null;
    await _tryApplyInitialSeek(forceAwait: true);
    if (initialVolume != null) {
      try {
        await _player!.setVolume(initialVolume.clamp(0.0, 100.0));
      } catch (_) {}
    }
    try {
      if (shouldPlay) {
        await _player!.play();
      } else {
        await _player!.pause();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPlaying = shouldPlay;
      });
    }
  }

  Future<void> _tryApplyInitialSeek({bool forceAwait = false}) async {
    if (_initialSyncApplied) return;
    if (_player == null) return;
    final ms = _pendingInitialSeekMs;
    if (ms == null || ms <= 0) {
      _initialSyncApplied = true;
      return;
    }
    Future<void> doSeek() async {
      try {
        await _player!.seek(Duration(milliseconds: ms));
        _pendingInitialSeekMs = null;
        _initialSyncApplied = true;
      } catch (_) {}
    }
    if (forceAwait) {
      await doSeek();
    } else {
      unawaited(doSeek());
    }
  }

  Future<void> _waitForReady({Duration timeout = const Duration(seconds: 2)}) async {
    try {
      // If already has duration, return quickly
      if (_player?.state.duration.inMilliseconds != 0) return;
      final d = await _player!.stream.duration
          .firstWhere((d) => d.inMilliseconds > 0)
          .timeout(timeout);
      if (mounted) {
        setState(() => _duration = d);
      }
    } catch (_) {
      // Timeout or stream closed: continue anyway
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _saveDebounce?.cancel();
    _videoWSub?.cancel();
    _videoHSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _overlayHideTimer?.cancel();
    _controller = null;
    _player?.dispose();
    // Best-effort send final state
    _sendState(closing: true);
    try {
      _ipc?.destroy();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          onPointerHover: (_) => _bumpOverlay(),
          onPointerMove: (_) => _bumpOverlay(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleOverlay,
            onPanStart: (_) async {
              // Click-hold and move to drag the window (outside overlay interactions)
              try {
                await windowManager.startDragging();
              } catch (_) {}
            },
            child: Stack(
              children: [
                if (_controller != null)
                  Positioned.fill(
                    child: Video(
                      controller: _controller!,
                      controls: NoVideoControls,
                      fill: Colors.black,
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator()),

                // Top-right quick buttons
                Positioned(
                  right: 8,
                  top: 8,
                  child: AnimatedOpacity(
                    opacity: _showOverlay ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Row(
                      children: [
                _circleButton(
                  icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                  onTap: () async {
                    if (_player == null) return;
                          if (_player!.state.playing) {
                            await _player!.pause();
                            setState(() => _isPlaying = false);
                          } else {
                            await _player!.play();
                            setState(() => _isPlaying = true);
                          }
                  },
                ),
                        const SizedBox(width: 8),
                        _circleButton(
                          icon: Icons.close,
                          onTap: () async {
                            try {
                              await windowManager.close();
                            } catch (_) {
                              if (context.mounted) {
                                Navigator.of(context).maybePop();
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom overlay controls: seek & volume
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: _showOverlay ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: _buildBottomControls(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  // Persist PiP window size so next launch restores it
  Future<void> _saveCurrentSize() async {
    try {
      final size = await windowManager.getSize();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('pip_w', size.width);
      await prefs.setDouble('pip_h', size.height);
    } catch (_) {}
  }

  void _scheduleSaveSize() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveCurrentSize);
  }

  void _maybeApplyVideoAspectRatio() async {
    if (!mounted) return;
    final w = _videoW;
    final h = _videoH;
    if (w != null && h != null && w > 0 && h > 0) {
      try {
        final ratio = w / h;
        await windowManager.setAspectRatio(ratio);

        // Adjust window size once to match video aspect ratio for first display.
        if (!_initialAspectApplied) {
          _initialAspectApplied = true;
          final current = await windowManager.getSize();
          final min = const Size(240, 135);
          final optionAWidth = current.height * ratio;
          final optionAHeight = current.height;
          final optionBHeight = current.width / ratio;
          final optionBWidth = current.width;
          final deltaA = (optionAWidth - current.width).abs();
          final deltaB = (optionBHeight - current.height).abs();
          double newW, newH;
          if (deltaA <= deltaB) {
            newW = optionAWidth;
            newH = optionAHeight;
          } else {
            newW = optionBWidth;
            newH = optionBHeight;
          }
          if (newW < min.width) {
            newW = min.width;
            newH = newW / ratio;
          }
          if (newH < min.height) {
            newH = min.height;
            newW = newH * ratio;
          }
          await windowManager.setSize(Size(newW, newH));
        }
      } catch (_) {}
    }
  }

  // Overlay helpers
  void _bumpOverlay() {
    if (!_showOverlay) setState(() => _showOverlay = true);
    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) _bumpOverlay();
  }

  Widget _buildBottomControls(BuildContext context) {
    int totalMs = _duration.inMilliseconds;
    if (totalMs < 0) totalMs = 0;
    int posMs = _position.inMilliseconds;
    if (posMs < 0) posMs = 0;
    if (posMs > totalMs) posMs = totalMs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seekbar row with compact volume
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () async {
                  if (_player == null) return;
                  if (_player!.state.playing) {
                    await _player!.pause();
                    setState(() => _isPlaying = false);
                  } else {
                    await _player!.play();
                    setState(() => _isPlaying = true);
                  }
                },
              ),
              const SizedBox(width: 8),
              Text(_formatTime(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: totalMs == 0 ? 0 : posMs.toDouble(),
                    min: 0,
                    max: (totalMs == 0 ? 1 : totalMs).toDouble(),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChangeStart: (_) => _seeking = true,
                    onChanged: (v) {
                      setState(() => _position = Duration(milliseconds: v.toInt()));
                    },
                    onChangeEnd: (v) async {
                      _seeking = false;
                      if (_player != null) {
                        await _player!.seek(Duration(milliseconds: v.toInt()));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatTime(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.volume_up, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              SizedBox(
                width: 90,
                child: Slider(
                  value: ((_player?.state.volume ?? 100).clamp(0, 100)).toDouble(),
                  min: 0,
                  max: 100,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white24,
                  onChanged: (v) async {
                    if (_player != null) {
                      await _player!.setVolume(v);
                      setState(() {});
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // WindowListener overrides
  @override
  void onWindowResized() {
    _scheduleSaveSize();
  }

  @override
  void onWindowClose() {
    // Best-effort save; may not always complete before process exit
    unawaited(_saveCurrentSize());
    _sendState(closing: true);
  }

  // Helpers copied from main player to support SMB -> UNC on Windows
  String _smbToUnc(String smbUrl) {
    try {
      final uri = Uri.parse(smbUrl);
      final host = uri.host;
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (host.isEmpty || segs.isEmpty) {
        return smbUrl.replaceFirst('smb://', r'\\').replaceAll('/', r'\\');
      }
      final path = segs.join(r'\\');
      return r'\\' + host + r'\\' + path;
    } catch (_) {
      return smbUrl.replaceFirst('smb://', r'\\').replaceAll('/', r'\\');
    }
  }

  String _normalizeToFileUri(String path) {
    if (Platform.isWindows) {
      if (path.startsWith('\\\\')) {
        final cleaned = path.replaceAll('\\', '/');
        final withoutLeading =
            cleaned.startsWith('//') ? cleaned.substring(2) : cleaned;
        return 'file://$withoutLeading';
      }
      final cleaned = path.replaceAll('\\', '/');
      return 'file:///$cleaned';
    }
    return path;
  }
}

extension on Socket {
  void writeln(String s) {
    add(utf8.encode('$s\n'));
  }
}

extension _IpcHelpers on _DesktopPipWindowState {
  Future<void> _initIpc() async {
    final port = widget.args['ipcPort'];
    final token = widget.args['ipcToken'];
    if (port is int && token is String) {
      _ipcPort = port;
      _ipcToken = token;
      try {
        final sock = await Socket.connect(InternetAddress.loopbackIPv4, port,
            timeout: const Duration(seconds: 2));
        _ipc = sock;
        // hello
        _ipc!.writeln(jsonEncode({
          'type': 'hello',
          'token': _ipcToken,
        }));
      } catch (_) {
        // ignore
      }
    }
  }

  void _sendState({bool closing = false}) {
    if (_ipc == null || _ipcToken == null) return;
    final msg = <String, dynamic>{
      'type': closing ? 'closing' : 'state',
      'token': _ipcToken,
      'positionMs': _position.inMilliseconds,
      'volume': (_player?.state.volume ?? 100).toDouble(),
      'playing': _player?.state.playing ?? _isPlaying,
    };
    try {
      _ipc!.writeln(jsonEncode(msg));
    } catch (_) {}
  }
}
