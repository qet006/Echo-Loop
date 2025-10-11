import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../providers/player_provider.dart';
import '../models/playback_settings.dart';
import '../services/subtitle_parser.dart';
import '../widgets/playback_controls.dart';
import '../widgets/sentence_list_view.dart';
import '../widgets/settings_panel.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<PlayerProvider>(
          builder: (context, player, child) {
            return Text(player.currentAudioItem?.name ?? 'Player');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsPanel(context),
          ),
        ],
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, player, child) {
          if (!player.hasAudio) {
            return const Center(
              child: Text('No audio loaded'),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 800;
              
              if (isWideScreen) {
                return _buildWideLayout(context, player);
              } else {
                return _buildNarrowLayout(context, player);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, PlayerProvider player) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(child: _buildTranscriptView(player)),
              _buildControlPanel(context, player),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: _buildSidePanel(player),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, PlayerProvider player) {
    return Column(
      children: [
        Expanded(child: _buildTranscriptView(player)),
        _buildControlPanel(context, player),
      ],
    );
  }

  Widget _buildTranscriptView(PlayerProvider player) {
    if (!player.hasSentences) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subtitles_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No transcript available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final displaySentences = player.settings.mode == PlaybackMode.bookmarkedOnly
        ? player.bookmarkedSentences
        : player.sentences;

    if (displaySentences.isEmpty && player.settings.mode == PlaybackMode.bookmarkedOnly) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No bookmarked sentences',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap ⭐ on sentences to bookmark them',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SentenceListView(
      sentences: displaySentences,
      currentIndex: player.currentSentenceIndex,
      bookmarkedIndices: player.bookmarkedIndices,
      onSentenceTap: (index) => player.playSentence(index),
      onBookmarkToggle: (index) => player.toggleBookmark(index),
    );
  }

  Widget _buildSidePanel(PlayerProvider player) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Playback Mode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildModeSelector(player),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildBookmarksList(player),
        ),
      ],
    );
  }

  Widget _buildModeSelector(PlayerProvider player) {
    return Column(
      children: [
        _buildModeOption(
          player,
          PlaybackMode.fullArticle,
          Icons.article,
          'Full Article',
        ),
        _buildModeOption(
          player,
          PlaybackMode.singleSentence,
          Icons.format_quote,
          'Single Sentence',
        ),
        _buildModeOption(
          player,
          PlaybackMode.bookmarkedOnly,
          Icons.bookmark,
          'Bookmarked Only',
        ),
      ],
    );
  }

  Widget _buildModeOption(
    PlayerProvider player,
    PlaybackMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = player.settings.mode == mode;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.blue : null),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: () {
          player.updateSettings(player.settings.copyWith(mode: mode));
        },
      ),
    );
  }

  Widget _buildBookmarksList(PlayerProvider player) {
    final bookmarks = player.bookmarkedSentences;
    
    if (bookmarks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No bookmarked sentences yet.\nTap ⭐ to bookmark sentences.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final sentence = bookmarks[index];
        return ListTile(
          leading: const Icon(Icons.bookmark, color: Colors.amber),
          title: Text(
            sentence.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(SubtitleParser.formatDuration(sentence.startTime)),
          onTap: () => player.playSentence(sentence.index),
        );
      },
    );
  }

  Widget _buildControlPanel(BuildContext context, PlayerProvider player) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressBar(player),
            PlaybackControls(player: player),
            _buildInfoBar(player),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: StreamBuilder(
        stream: player.audioPlayer.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final total = player.totalDuration ?? Duration.zero;
          
          return ProgressBar(
            progress: position,
            total: total,
            onSeek: (duration) => player.seek(duration),
            barHeight: 4,
            thumbRadius: 6,
            timeLabelTextStyle: const TextStyle(fontSize: 12),
          );
        },
      ),
    );
  }

  Widget _buildInfoBar(PlayerProvider player) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getModeIcon(player.settings.mode),
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                _getModeLabel(player.settings.mode),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          if (player.settings.loopEnabled)
            Row(
              children: [
                Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  player.settings.loopCount == 0
                      ? '∞'
                      : 'x${player.settings.loopCount}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          Text(
            '${player.settings.playbackSpeed}x',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.fullArticle:
        return Icons.article;
      case PlaybackMode.singleSentence:
        return Icons.format_quote;
      case PlaybackMode.bookmarkedOnly:
        return Icons.bookmark;
    }
  }

  String _getModeLabel(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.fullArticle:
        return 'Full Article';
      case PlaybackMode.singleSentence:
        return 'Single Sentence';
      case PlaybackMode.bookmarkedOnly:
        return 'Bookmarked Only';
    }
  }

  void _showSettingsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SettingsPanel(),
    );
  }
}
