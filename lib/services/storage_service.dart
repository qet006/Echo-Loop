import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_item.dart';
import '../models/playback_settings.dart';

class StorageService {
  static const String _audioLibraryKey = 'audio_library';
  static const String _settingsKey = 'playback_settings';
  static const String _bookmarksKey = 'bookmarks_';

  // Audio Library
  static Future<List<AudioItem>> loadAudioLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_audioLibraryKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => AudioItem.fromJson(json)).toList();
    } catch (e) {
      print('Error loading audio library: $e');
      return [];
    }
  }

  static Future<void> saveAudioLibrary(List<AudioItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_audioLibraryKey, jsonString);
  }

  // Playback Settings
  static Future<PlaybackSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);
    if (jsonString == null) return PlaybackSettings();

    try {
      return PlaybackSettings.fromJson(json.decode(jsonString));
    } catch (e) {
      print('Error loading settings: $e');
      return PlaybackSettings();
    }
  }

  static Future<void> saveSettings(PlaybackSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(settings.toJson());
    await prefs.setString(_settingsKey, jsonString);
  }

  // Bookmarks for specific audio
  static Future<Set<int>> loadBookmarks(String audioId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_bookmarksKey$audioId');
    if (jsonString == null) return {};

    try {
      final List<dynamic> indices = json.decode(jsonString);
      return indices.cast<int>().toSet();
    } catch (e) {
      print('Error loading bookmarks: $e');
      return {};
    }
  }

  static Future<void> saveBookmarks(String audioId, Set<int> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(bookmarks.toList());
    await prefs.setString('$_bookmarksKey$audioId', jsonString);
  }
}
