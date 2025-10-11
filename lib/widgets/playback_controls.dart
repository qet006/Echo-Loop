import 'package:flutter/material.dart';
import '../providers/player_provider.dart';

class PlaybackControls extends StatelessWidget {
  final PlayerProvider player;

  const PlaybackControls({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 32,
            onPressed: player.hasSentences ? () => player.previousSentence() : null,
            tooltip: 'Previous Sentence',
          ),
          const SizedBox(width: 12),
          _buildPlayPauseButton(context),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 32,
            onPressed: player.hasSentences ? () => player.nextSentence() : null,
            tooltip: 'Next Sentence',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
        iconSize: 40,
        color: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          if (player.isPlaying) {
            player.pause();
          } else {
            player.play();
          }
        },
        tooltip: player.isPlaying ? 'Pause' : 'Play',
      ),
    );
  }
}
