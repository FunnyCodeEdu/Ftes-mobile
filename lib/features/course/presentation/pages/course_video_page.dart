import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:ui' show FontFeature;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../core/constants/app_constants.dart' as app_constants;
import '../../../../core/widgets/youtube_player_widget.dart';
import '../../../../routes/app_routes.dart';
import '../viewmodels/course_video_viewmodel.dart';
import '../../domain/constants/video_constants.dart';
import 'web_hls_helper.dart';

class CourseVideoPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final String courseTitle;
  final String videoUrl;
  final String courseId;
  final String? type; // VIDEO, DOCUMENT, EXERCISE
  final String? descriptions; // Lesson descriptions

  const CourseVideoPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.courseTitle,
    required this.videoUrl,
    required this.courseId,
    this.type,
    this.descriptions,
  });

  @override
  State<CourseVideoPage> createState() => _CourseVideoPageState();
}

class _CourseVideoPageState extends State<CourseVideoPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isLoadingVideo = true;
  bool _isYouTubeVideo = false;
  String? _hlsVideoUrl;

  // Animation & UI state
  bool _showControls = true;
  bool _isDraggingProgress = false;
  double _dragProgress = 0.0;
  double _volume = 1.0;
  bool _isMuted = false;
  bool _showVolumeSlider = false;
  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;

  // Double tap to seek
  bool _showSeekIndicator = false;
  int _seekSeconds = 0; // +10 or -10

  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimController,
      curve: Curves.easeInOut,
    );
    _controlsAnimController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo();
    });
  }

  /// Optimized video initialization with parallel async operations
  Future<void> _initializeVideo() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingVideo = true;
        });
      }

      // Check lesson type - if not VIDEO, skip video loading and show popup
      if (widget.type != null && widget.type != 'VIDEO') {
        debugPrint(
          '📄 Lesson type is ${widget.type}, not VIDEO. Showing content popup.',
        );
        if (mounted) {
          setState(() {
            _isLoadingVideo = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showContentDialog();
          });
        }
        return;
      }

      // Get userId and access token in parallel
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(app_constants.AppConstants.keyUserId);

      if (userId == null || userId.isEmpty) {
        _showNotEnrolledError();
        return;
      }

      // Initialize video via optimized ViewModel method
      if (!mounted) return;
      final viewModel = Provider.of<CourseVideoViewModel>(
        context,
        listen: false,
      );
      final canWatch = await viewModel.initializeVideo(
        userId,
        widget.courseId,
        widget.videoUrl,
      );
      if (!mounted) return;

      if (!canWatch) {
        _showNotEnrolledError();
        return;
      }

      // Load video based on type
      final videoType = viewModel.videoType;

      if (videoType == VideoConstants.videoTypeYoutube ||
          videoType == VideoConstants.videoTypeVimeo) {
        // External video (YouTube/Vimeo) - use web player
        if (mounted) {
          setState(() {
            _isYouTubeVideo = true;
            _isLoadingVideo = false;
          });
        }
      } else if (videoType == VideoConstants.videoTypeExternal) {
        // Direct URL - play directly
        await _setupDirectVideo();
      } else {
        // Internal HLS video - load playlist from API
        await _setupHlsVideo();
      }
    } catch (e) {
      debugPrint('❌ Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
    }
  }

  Future<void> _setupHlsVideo() async {
    try {
      // Get access token
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(
        app_constants.AppConstants.keyAccessToken,
      );

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Access token not found');
      }

      debugPrint('🎥 Setting up internal HLS video: ${widget.videoUrl}');

      // Load video playlist via ViewModel (calls API)
      if (!mounted) return;
      final viewModel = Provider.of<CourseVideoViewModel>(
        context,
        listen: false,
      );
      await viewModel.loadVideoPlaylist(widget.videoUrl);

      if (!mounted) return;
      if (viewModel.errorMessage != null) {
        // Check if it's a 404 error (API not implemented or video not found)
        if (viewModel.errorMessage!.contains('404') ||
            viewModel.errorMessage!.contains('Not Found')) {
          throw Exception(VideoConstants.errorApiNotImplemented);
        }
        throw Exception(viewModel.errorMessage);
      }

      if (viewModel.videoPlaylist == null) {
        throw Exception(VideoConstants.errorVideoLoadFailed);
      }

      // Get video playlist from API
      final playlist = viewModel.videoPlaylist!;

      String? videoUrl;
      // Tất cả platforms ưu tiên proxy URL (chỉ có proxy là dùng được)
      if (playlist.proxyPlaylistUrl != null &&
          playlist.proxyPlaylistUrl!.isNotEmpty) {
        videoUrl = playlist.proxyPlaylistUrl;
        debugPrint('✅ Using proxy URL (only proxy is available): $videoUrl');
      } else if (playlist.cdnPlaylistUrl.isNotEmpty) {
        videoUrl = playlist.cdnPlaylistUrl;
        debugPrint('⚠️ Fallback to CDN URL: $videoUrl');
      } else if (playlist.presignedUrl != null &&
          playlist.presignedUrl!.isNotEmpty) {
        videoUrl = playlist.presignedUrl;
        debugPrint('⚠️ Fallback to presigned URL: $videoUrl');
      } else {
        throw Exception('Không tìm thấy URL video hợp lệ từ server');
      }

      // For web platform, use HLS player directly (HTML5 video supports HLS natively)
      if (kIsWeb) {
        // Web doesn't support VideoPlayerController for HLS properly, use HLS URL directly
        _hlsVideoUrl = videoUrl!;
        debugPrint('🌐 Web platform - Using HLS URL for HTML5 video player');
        debugPrint('   $_hlsVideoUrl');
      } else {
        // Mobile: dùng VideoPlayerController.networkUrl (hỗ trợ HLS native)
        debugPrint(
          '📱 Mobile platform - Initializing VideoPlayerController with HLS',
        );
        debugPrint('   URL: $videoUrl');
        debugPrint(
          '⚠️ Note: If publicly available m3u8 fails, backend must transform m3u8 segments to proxy',
        );

        // Initialize VideoPlayerController với HLS URL
        // networkUrl() là API mới hỗ trợ HLS native trên Android/iOS
        // Proxy URL: cần Authorization header để proxy có thể fetch từ S3
        // Presigned URL: S3 signed URL có auth trong query params, không cần header
        final isPresigned =
            playlist.presignedUrl != null &&
            playlist.presignedUrl!.isNotEmpty &&
            videoUrl == playlist.presignedUrl;

        final isProxy =
            playlist.proxyPlaylistUrl != null &&
            playlist.proxyPlaylistUrl!.isNotEmpty &&
            videoUrl == playlist.proxyPlaylistUrl;

        debugPrint('🔑 Is presigned URL: $isPresigned');
        debugPrint('🔑 Is proxy URL: $isProxy');

        // Build headers based on URL type
        final Map<String, String> headers = {
          'Referer': 'https://ftes.vn',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0 Mobile Safari/537.36',
        };

        // Proxy URL cần Authorization header để backend có thể fetch từ S3
        if (isProxy && accessToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $accessToken';
          debugPrint(
            '🔑 Using headers: Authorization + Referer + User-Agent for proxy URL',
          );
        } else if (isPresigned) {
          // Presigned URL không cần Authorization header (auth trong query params)
          debugPrint(
            '🔑 Using headers: Referer + User-Agent for presigned URL',
          );
        } else {
          // CDN URL cần Referer để bypass Hotlink Protection
          debugPrint(
            '🔑 Using headers: Referer + User-Agent for BunnyCDN Hotlink Protection bypass',
          );
        }

        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl!),
          httpHeaders: headers,
        );

        // Initialize và play video
        await _controller!.initialize();
        await _controller!.play();

        // Add listener to update UI when video position changes
        _controller!.addListener(() {
          if (mounted) {
            setState(() {
              // This will trigger UI update when video position changes
            });
          }
        });

        debugPrint('✅ Mobile video initialized and playing');
      }

      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error setting up HLS video: $e');
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });

        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lỗi phát video'),
            content: Text('Không thể tải video.\n\n${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close video page
                },
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _setupDirectVideo() async {
    try {
      // Get access token
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(
        app_constants.AppConstants.keyAccessToken,
      );

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Access token not found');
      }

      debugPrint('🎥 Setting up direct video URL: ${widget.videoUrl}');

      // Initialize video player with auth header
      // ignore: deprecated_member_use
      _controller = VideoPlayerController.network(
        widget.videoUrl,
        httpHeaders: {'Authorization': 'Bearer $accessToken'},
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }

      _controller!.play();
    } catch (e) {
      debugPrint('❌ Error setting up direct video: $e');
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lỗi phát video'),
            content: Text('Không thể phát video.\n\n${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showNotEnrolledError() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(VideoConstants.notEnrolledTitle),
        content: const Text(VideoConstants.notEnrolledMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close video page
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (kIsWeb) {
      getWebHlsHelper().cleanupWrapper();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controlsAnimController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _showContentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E293B), // Dark blue color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.type ?? 'Content',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(color: Colors.grey, height: 24),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Html(
                      data: widget.videoUrl,
                      onLinkTap: (url, attributes, element) {
                        if (url == null) return;
                        UrlHelper.openExternalUrl(context, url: url);
                      },
                      style: {
                        "body": Style(
                          color: Colors.white,
                          margin: Margins.zero,
                        ),
                        "a": Style(
                          color: const Color(0xFF0961F5), // Blue links
                          textDecoration: TextDecoration.underline,
                        ),
                        "p": Style(margin: Margins.only(bottom: 8)),
                        "ul": Style(
                          margin: Margins.only(bottom: 8),
                          padding: HtmlPaddings.zero,
                        ),
                        "li": Style(margin: Margins.only(bottom: 4)),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoContent() {
    // Check if lesson type is not VIDEO - show document icon
    if (widget.type != null && widget.type != 'VIDEO') {
      return GestureDetector(
        onTap: _showContentDialog,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 100,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                widget.lessonTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to view content',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show external video player (YouTube/Vimeo) if external video
    if (_isYouTubeVideo) {
      final viewModel = Provider.of<CourseVideoViewModel>(
        context,
        listen: false,
      );
      final videoType = viewModel.videoType;

      // For both YouTube and Vimeo, we use YouTubePlayerWidget
      // (it can handle both via iframe) - make it smaller and more compact
      return Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(40.0), // Add padding to make smaller
          child: Center(
            child: YouTubePlayerWidget(
              videoUrl: widget.videoUrl,
              videoType: videoType ?? VideoConstants.videoTypeYoutube,
            ),
          ),
        ),
      );
    }

    // HLS - Web: HTML5 layer
    if (kIsWeb && _hlsVideoUrl != null) {
      return _buildWebHlsPlayer(_hlsVideoUrl!);
    }

    // Show video player if initialized (for mobile/desktop HLS hoặc direct video)
    if (_controller != null && _controller!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: _buildVideoPlayerWithControls(),
        ),
      );
    }

    // Show loading indicator
    if (_isLoadingVideo) {
      return _buildLoadingIndicator();
    }

    // Show error or empty state
    return _buildEmptyState();
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0961F5)),
      ),
    );
  }

  Widget _buildVideoPlayerWithControls() {
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final buffered = _controller!.value.buffered;

    double progress = 0.0;
    if (duration.inMilliseconds > 0) {
      if (_isDraggingProgress) {
        progress = _dragProgress;
      } else {
        progress = position.inMilliseconds / duration.inMilliseconds;
      }
    }

    final isPlaying = _controller!.value.isPlaying;

    return GestureDetector(
      onTap: _handleTap,
      onDoubleTapDown: (details) => _handleDoubleTap(details.globalPosition),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Video
          Positioned.fill(child: VideoPlayer(_controller!)),

          // Double tap seek zones
          _buildDoubleTapZones(),

          // Seek indicator (double tap feedback)
          if (_showSeekIndicator) _buildSeekIndicator(),

          // Volume slider overlay
          if (_showVolumeSlider) _buildVolumeSliderOverlay(),

          // Auto-hide controls overlay
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _showControls ? _controlsAnimation.value : 0.0,
                child: IgnorePointer(ignoring: !_showControls, child: child),
              );
            },
            child: _buildControlsOverlay(
              isPlaying: isPlaying,
              progress: progress,
              duration: duration,
              buffered: buffered,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _controlsAnimController.forward();
        _scheduleHideControls();
      } else {
        _controlsAnimController.reverse();
      }
    });
  }

  void _handleDoubleTap(Offset globalPosition) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeftSide = globalPosition.dx < screenWidth / 2;

    if (isLeftSide) {
      // Rewind 10 seconds
      final newPosition =
          _controller!.value.position - const Duration(seconds: 10);
      _controller!.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
      _showSeekAnimation(-10);
    } else {
      // Forward 10 seconds
      final newPosition =
          _controller!.value.position + const Duration(seconds: 10);
      final maxDuration = _controller!.value.duration;
      _controller!.seekTo(
        newPosition > maxDuration ? maxDuration : newPosition,
      );
      _showSeekAnimation(10);
    }
  }

  void _showSeekAnimation(int seconds) {
    setState(() {
      _seekSeconds = seconds;
      _showSeekIndicator = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showSeekIndicator = false;
        });
      }
    });
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _showControls && _controller?.value.isPlaying == true) {
        _controlsAnimController.reverse();
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Widget _buildDoubleTapZones() {
    return Row(
      children: [
        // Left zone - rewind
        Expanded(
          child: GestureDetector(
            onDoubleTap: () {
              final newPos =
                  _controller!.value.position - const Duration(seconds: 10);
              _controller!.seekTo(newPos.isNegative ? Duration.zero : newPos);
              _showSeekAnimation(-10);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Right zone - forward
        Expanded(
          child: GestureDetector(
            onDoubleTap: () {
              final newPos =
                  _controller!.value.position + const Duration(seconds: 10);
              final maxDur = _controller!.value.duration;
              _controller!.seekTo(newPos > maxDur ? maxDur : newPos);
              _showSeekAnimation(10);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildSeekIndicator() {
    final isForward = _seekSeconds > 0;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForward ? Icons.forward_10 : Icons.replay_10,
              color: Colors.white,
              size: 44,
            ),
            const SizedBox(width: 12),
            Text(
              '${_seekSeconds.abs()}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeSliderOverlay() {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          width: 240,
          height: 360,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    _controller?.setVolume(_isMuted ? 0 : _volume);
                  });
                },
                child: Icon(
                  _isMuted
                      ? Icons.volume_off
                      : (_volume > 0.5 ? Icons.volume_up : Icons.volume_down),
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                      activeTrackColor: const Color(0xFF0961F5),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                      thumbColor: Colors.white,
                      overlayColor: const Color(
                        0xFF0961F5,
                      ).withValues(alpha: 0.3),
                    ),
                    child: Slider(
                      value: _isMuted ? 0 : _volume,
                      onChanged: (val) {
                        setState(() {
                          _volume = val;
                          _isMuted = val == 0;
                          _controller?.setVolume(val);
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${(_volume * 100).round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay({
    required bool isPlaying,
    required double progress,
    required Duration duration,
    required List<DurationRange> buffered,
  }) {
    return Column(
      children: [
        // TOP BAR: Back + Title + Settings
        _buildTopBar(),

        const Spacer(),

        // CENTER: Play/Pause big button
        Center(
          child: AnimatedScale(
            scale: isPlaying ? 1.0 : 1.25,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isPlaying) {
                    _controller?.pause();
                  } else {
                    _controller?.play();
                    _scheduleHideControls();
                  }
                });
              },
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 54,
                ),
              ),
            ),
          ),
        ),

        const Spacer(),

        // BOTTOM BAR: Progress + Controls
        _buildBottomBar(progress, duration, buffered),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back button
            _buildControlButton(
              icon: Icons.arrow_back_ios_new,
              onPressed: () => Navigator.pop(context),
              size: 52,
              iconSize: 26,
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.lessonTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.courseTitle.isNotEmpty)
                    Text(
                      widget.courseTitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Playback speed button
            _buildControlButton(
              icon: Icons.speed,
              onPressed: _showPlaybackSpeedMenu,
              size: 52,
              iconSize: 26,
              label: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    double progress,
    Duration duration,
    List<DurationRange> buffered,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar + time
            Row(
              children: [
                // Time current - lớn hơn và rõ ràng hơn
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(
                      _isDraggingProgress
                          ? Duration(
                              milliseconds: (progress * duration.inMilliseconds)
                                  .round(),
                            )
                          : _controller!.value.position,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Progress bar
                Expanded(
                  child: _buildProgressBar(progress, duration, buffered),
                ),
                const SizedBox(width: 12),
                // Time total - lớn hơn và rõ ràng hơn
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Control buttons row - thiết kế hiện đại hơn
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left controls: Volume + Seek
                Row(
                  children: [
                    // Volume button với background
                    _buildControlButtonModern(
                      icon: _isMuted
                          ? Icons.volume_off
                          : (_volume > 0.5
                                ? Icons.volume_up
                                : Icons.volume_down),
                      onPressed: () {
                        setState(() {
                          _showVolumeSlider = !_showVolumeSlider;
                        });
                      },
                      size: 56,
                      iconSize: 28,
                    ),
                    const SizedBox(width: 12),
                    // Seek -10 với background
                    _buildControlButtonModern(
                      icon: Icons.replay_10,
                      onPressed: () {
                        final newPos =
                            _controller!.value.position -
                            const Duration(seconds: 10);
                        _controller!.seekTo(
                          newPos.isNegative ? Duration.zero : newPos,
                        );
                      },
                      size: 52,
                      iconSize: 26,
                    ),
                    // Seek +10 với background
                    _buildControlButtonModern(
                      icon: Icons.forward_10,
                      onPressed: () {
                        final newPos =
                            _controller!.value.position +
                            const Duration(seconds: 10);
                        final maxDur = _controller!.value.duration;
                        _controller!.seekTo(newPos > maxDur ? maxDur : newPos);
                      },
                      size: 52,
                      iconSize: 26,
                    ),
                  ],
                ),
                // Right controls: Picture-in-Picture + Fullscreen
                Row(
                  children: [
                    // Picture-in-Picture button (nếu hỗ trợ)
                    if (_controller?.value.isPlaying == true)
                      _buildControlButtonModern(
                        icon: Icons.picture_in_picture_alt,
                        onPressed: () {
                          // PiP functionality có thể thêm sau
                        },
                        size: 52,
                        iconSize: 24,
                      ),
                    const SizedBox(width: 8),
                    // Fullscreen button với background
                    _buildControlButtonModern(
                      icon: _isFullscreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      onPressed: _toggleFullscreen,
                      size: 56,
                      iconSize: 28,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Thêm state cho tooltip
  bool _showSeekTooltip = false;
  String _seekTooltipText = '';

  Widget _buildProgressBar(
    double progress,
    Duration duration,
    List<DurationRange> buffered,
  ) {
    final currentPosition = Duration(
      milliseconds: (progress * duration.inMilliseconds).round(),
    );

    return GestureDetector(
      onHorizontalDragStart: (_) {
        setState(() {
          _isDraggingProgress = true;
          _dragProgress = progress;
          _showSeekTooltip = true;
          _seekTooltipText = _formatDuration(currentPosition);
        });
      },
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        // Tính toán vị trí tương đối với progress bar
        final progressBarWidth = box.size.width;
        final localX = details.localPosition.dx.clamp(0.0, progressBarWidth);
        final newProgress = (localX / progressBarWidth).clamp(0.0, 1.0);
        final newPosition = Duration(
          milliseconds: (newProgress * duration.inMilliseconds).round(),
        );
        setState(() {
          _dragProgress = newProgress;
          _seekTooltipText = _formatDuration(newPosition);
        });
      },
      onHorizontalDragEnd: (_) {
        final newPos = Duration(
          milliseconds: (_dragProgress * duration.inMilliseconds).round(),
        );
        _controller!.seekTo(newPos);
        setState(() {
          _isDraggingProgress = false;
          _showSeekTooltip = false;
        });
      },
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox;
        final progressBarWidth = box.size.width;
        final localX = details.localPosition.dx.clamp(0.0, progressBarWidth);
        final newProgress = (localX / progressBarWidth).clamp(0.0, 1.0);
        final newPos = Duration(
          milliseconds: (newProgress * duration.inMilliseconds).round(),
        );
        _controller!.seekTo(newPos);
      },
      child: SizedBox(
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Buffered bar - KÍCH THƯỚC LỚN HƠN
            if (buffered.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: Row(
                    children: buffered.map((range) {
                      final startMs = range.start.inMilliseconds.toDouble();
                      final endMs = range.end.inMilliseconds.toDouble();
                      final start = duration.inMilliseconds > 0
                          ? startMs / duration.inMilliseconds
                          : 0.0;
                      final end = duration.inMilliseconds > 0
                          ? endMs / duration.inMilliseconds
                          : 0.0;
                      return Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (end - start).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Progress track nền - KÍCH THƯỚC LỚN HƠN
            Container(
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),

            // Progress đã phát - KÍCH THƯỚC LỚN HƠN
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: _isDraggingProgress ? 20 : 16,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0961F5), Color(0xFF3B82F6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0961F5).withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Progress handle - lớn hơn và rõ ràng hơn
            Positioned(
              left: 0,
              right: 0,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isDraggingProgress ? 80 : 72,
                    height: _isDraggingProgress ? 80 : 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0961F5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0961F5).withValues(alpha: 0.7),
                          blurRadius: _isDraggingProgress ? 20 : 14,
                          spreadRadius: _isDraggingProgress ? 5 : 3,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: _isDraggingProgress ? 22 : 16,
                        height: _isDraggingProgress ? 22 : 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Tooltip hiển thị thời gian khi kéo - KÍCH THƯỚC LỚN HƠN
            if (_showSeekTooltip)
              Positioned(
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -65),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFF0961F5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _seekTooltipText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 48,
    double iconSize = 24,
    Widget? label,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: iconSize),
            if (label != null) ...[const SizedBox(height: 2), label],
          ],
        ),
      ),
    );
  }

  // Nút điều khiển hiện đại với background
  Widget _buildControlButtonModern({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 52,
    double iconSize = 26,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  void _showPlaybackSpeedMenu() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tốc độ phát',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: speeds.map((speed) {
                final isSelected = _playbackSpeed == speed;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _playbackSpeed = speed;
                      _controller?.setPlaybackSpeed(speed);
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0961F5)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0961F5)
                            : Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _toggleFullscreen() async {
    if (_isFullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  void _initializeHlsPlayer(String hlsUrl) {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getWebHlsHelper().initHlsPlayer(hlsUrl);
    });
  }

  Widget _buildWebHlsPlayer(String hlsUrl) {
    _initializeHlsPlayer(hlsUrl);
    // Return a container with low opacity to ensure Flutter widgets render on top
    return Container(
      color: Colors.transparent.withValues(alpha: 0.01),
      width: double.infinity,
      height: double.infinity,
    );
  }

  // Removed legacy web HLS builder (unused)

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Video not available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned.fill(child: _buildVideoContent()),
            // Chat With AI button
            if (!_isYouTubeVideo && _controller == null && !_isLoadingVideo)
              Positioned(
                bottom: 20,
                right: 20,
                child: IgnorePointer(
                  ignoring: false,
                  child: GestureDetector(
                    onTap: () {
                      AppRoutes.navigateToAiChat(
                        context,
                        lessonId: widget.lessonId,
                        lessonTitle: widget.lessonTitle,
                        videoId: widget.videoUrl,
                        lessonDescription: widget.descriptions,
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0961F5),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            // Bottom indicator
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 134,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E6EA),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
