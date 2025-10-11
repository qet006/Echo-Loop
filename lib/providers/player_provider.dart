import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_item.dart';
import '../models/sentence.dart';
import '../models/playback_settings.dart';
import '../services/subtitle_parser.dart';
import '../services/storage_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  AudioItem? _currentAudioItem;
  List<Sentence> _sentences = [];
  int? _currentSentenceIndex;
  PlaybackSettings _settings = PlaybackSettings();
  Set<int> _bookmarkedIndices = {};
  
  bool _isLoading = false;
  int _currentSentenceLoopCount = 0;  // 当前句子的循环次数
  int _currentAudioLoopCount = 0;     // 当前音频的循环次数
  Timer? _pauseTimer;
  Timer? _sentenceEndTimer;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  bool _isDisposed = false;

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  AudioItem? get currentAudioItem => _currentAudioItem;
  List<Sentence> get sentences => _sentences;
  List<Sentence> get bookmarkedSentences => 
      _sentences.where((s) => _bookmarkedIndices.contains(s.index)).toList();
  int? get currentSentenceIndex => _currentSentenceIndex;
  Sentence? get currentSentence => 
      _currentSentenceIndex != null && _currentSentenceIndex! < _sentences.length
          ? _sentences[_currentSentenceIndex!]
          : null;
  PlaybackSettings get settings => _settings;
  Set<int> get bookmarkedIndices => _bookmarkedIndices;
  bool get isLoading => _isLoading;
  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;
  bool get hasAudio => _currentAudioItem != null;
  bool get hasSentences => _sentences.isNotEmpty;

  PlayerProvider() {
    _loadSettings();
    _setupListeners();
  }

  Future<void> _loadSettings() async {
    _settings = await StorageService.loadSettings();
    notifyListeners();
  }

  void _setupListeners() {
    _positionSubscription = _audioPlayer.positionStream.listen(_onPositionChanged);
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(_onPlayerStateChanged);
  }

  void _onPositionChanged(Duration position) {
    _updateCurrentSentence(position);
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      _handlePlaybackCompleted();
    }
    notifyListeners();
  }

  void _updateCurrentSentence(Duration position) {
    if (_sentences.isEmpty) return;

    final index = _sentences.indexWhere(
      (s) => position >= s.startTime && position < s.endTime,
    );

    if (index != -1 && index != _currentSentenceIndex) {
      _currentSentenceIndex = index;
      notifyListeners();
    }
  }

  Future<void> loadAudio(AudioItem audioItem) async {
    if (_currentAudioItem?.id == audioItem.id) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Stop current playback
      await stop();

      _currentAudioItem = audioItem;
      _sentences = [];
      _currentSentenceIndex = null;
      _currentSentenceLoopCount = 0;
      _currentAudioLoopCount = 0;

      // Load audio
      try {
        await _audioPlayer.setFilePath(audioItem.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);
      } catch (e) {
        print('Error loading audio file: $e');
        _currentAudioItem = null;
        rethrow;
      }

      // Load transcript if available
      if (audioItem.hasTranscript) {
        try {
          _sentences = await SubtitleParser.parseSubtitle(audioItem.transcriptPath!);
        } catch (e) {
          print('Error loading transcript: $e');
          // Continue without transcript
        }
      }

      // Load bookmarks
      try {
        _bookmarkedIndices = await StorageService.loadBookmarks(audioItem.id);
        
        // Update sentence bookmark status
        for (var sentence in _sentences) {
          sentence.isBookmarked = _bookmarkedIndices.contains(sentence.index);
        }
      } catch (e) {
        print('Error loading bookmarks: $e');
        _bookmarkedIndices = {};
      }

      // Set initial sentence to first sentence if available
      if (_sentences.isNotEmpty) {
        _currentSentenceIndex = 0;
        await _audioPlayer.seek(_sentences[0].startTime);
      }

    } catch (e) {
      print('Error loading audio: $e');
      _currentAudioItem = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 播放音频：直接播放整个音频
  Future<void> play() async {
    if (_currentAudioItem == null) return;
    await _audioPlayer.play();
  }

  // 暂停播放
  Future<void> pause() async {
    await _audioPlayer.pause();
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
  }

  // 停止播放
  Future<void> stop() async {
    await _audioPlayer.stop();
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
    _currentSentenceLoopCount = 0;
    _currentAudioLoopCount = 0;
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // 播放单个句子（用于逐句精听）
  Future<void> playSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;

    _currentSentenceIndex = index;
    _currentSentenceLoopCount = 0;
    
    await _playSentenceInternal(index);
  }

  // 内部方法：播放句子的实际逻辑
  Future<void> _playSentenceInternal(int index) async {
    if (_isDisposed) return;
    
    final sentence = _sentences[index];
    await _audioPlayer.seek(sentence.startTime);
    await _audioPlayer.play();

    // 取消现有的句子结束计时器
    _sentenceEndTimer?.cancel();
    
    // 根据播放速度调整计时器，使其在音频播放到句子结束时触发
    final speed = _audioPlayer.speed == 0 ? 1.0 : _audioPlayer.speed;
    final scaledMs = (sentence.duration.inMilliseconds / speed).round();
    final duration = Duration(milliseconds: scaledMs);
    _sentenceEndTimer = Timer(duration, () async {
      if (!_isDisposed && _audioPlayer.playing && _currentSentenceIndex == index) {
        await _audioPlayer.pause();
        await _handleSentenceCompleted();
      }
    });
  }

  // 处理句子播放完成
  Future<void> _handleSentenceCompleted() async {
    if (_isDisposed) return;

    // 检查是否需要循环当前句子
    if (_settings.loopEnabled) {
      _currentSentenceLoopCount++;
      
      // 句子循环次数：1-20次
      final shouldLoop = _currentSentenceLoopCount < _settings.loopCount;
      
      if (shouldLoop && _currentSentenceIndex != null) {
        _pauseTimer?.cancel();
        // 等待指定的间隔时间后重新播放句子
        _pauseTimer = Timer(_settings.pauseInterval, () async {
          if (!_isDisposed) {
            await _playSentenceInternal(_currentSentenceIndex!);
          }
        });
        return;
      }
    }
    
    // 句子循环完成或未启用循环，不自动播放下一句
    // 用户需要手动点击下一句按钮
    _currentSentenceLoopCount = 0;
  }

  // 处理整个音频播放完成
  void _handlePlaybackCompleted() {
    if (_isDisposed) return;
    
    // 检查是否启用音频循环
    // loopAudio: 0=无穷循环, 1-10=循环指定次数
    if (_settings.loopAudioEnabled) {
      _currentAudioLoopCount++;
      
      // 判断是否继续循环
      final shouldLoop = _settings.loopAudio == 0 || _currentAudioLoopCount < _settings.loopAudio;
      
      if (shouldLoop) {
        _pauseTimer?.cancel();
        // 等待间隔时间后重新播放整个音频
        _pauseTimer = Timer(_settings.pauseInterval, () async {
          if (!_isDisposed) {
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();
          }
        });
      } else {
        // 循环完成，重置计数
        _currentAudioLoopCount = 0;
      }
    }
  }

  // 跳转到下一句
  Future<void> nextSentence() async {
    if (_sentences.isEmpty) return;

    int nextIndex;
    if (_currentSentenceIndex == null) {
      nextIndex = 0;
    } else if (_currentSentenceIndex! >= _sentences.length - 1) {
      // 已是最后一句，循环到第一句
      nextIndex = 0;
    } else {
      nextIndex = _currentSentenceIndex! + 1;
    }

    _currentSentenceIndex = nextIndex;
    await seek(_sentences[nextIndex].startTime);
    notifyListeners();
  }

  // 跳转到上一句
  Future<void> previousSentence() async {
    if (_sentences.isEmpty) return;

    int prevIndex;
    if (_currentSentenceIndex == null) {
      prevIndex = _sentences.length - 1;
    } else if (_currentSentenceIndex! <= 0) {
      // 已是第一句，循环到最后一句
      prevIndex = _sentences.length - 1;
    } else {
      prevIndex = _currentSentenceIndex! - 1;
    }

    _currentSentenceIndex = prevIndex;
    await seek(_sentences[prevIndex].startTime);
    notifyListeners();
  }

  Future<void> toggleBookmark(int index) async {
    if (_bookmarkedIndices.contains(index)) {
      _bookmarkedIndices.remove(index);
      _sentences[index].isBookmarked = false;
    } else {
      _bookmarkedIndices.add(index);
      _sentences[index].isBookmarked = true;
    }

    if (_currentAudioItem != null) {
      await StorageService.saveBookmarks(_currentAudioItem!.id, _bookmarkedIndices);
    }
    
    notifyListeners();
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    _settings = newSettings;
    await _audioPlayer.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
