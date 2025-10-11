import 'package:flutter/foundation.dart';
import '../models/audio_item.dart';
import '../services/storage_service.dart';

class AudioLibraryProvider extends ChangeNotifier {
  List<AudioItem> _audioItems = [];
  bool _isLoading = false;

  List<AudioItem> get audioItems => _audioItems;
  bool get isLoading => _isLoading;
  bool get isEmpty => _audioItems.isEmpty;

  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();

    _audioItems = await StorageService.loadAudioLibrary();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addAudioItem(AudioItem item) async {
    _audioItems.add(item);
    await _saveLibrary();
    notifyListeners();
  }

  Future<void> removeAudioItem(String id) async {
    _audioItems.removeWhere((item) => item.id == id);
    await _saveLibrary();
    notifyListeners();
  }

  Future<void> updateAudioItem(AudioItem updatedItem) async {
    final index = _audioItems.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _audioItems[index] = updatedItem;
      await _saveLibrary();
      notifyListeners();
    }
  }

  AudioItem? getItemById(String id) {
    try {
      return _audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveLibrary() async {
    await StorageService.saveAudioLibrary(_audioItems);
  }
}
