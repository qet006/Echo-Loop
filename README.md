# Listen Master - Professional English Listening Practice App

A professional English listening practice application built with Flutter, designed for language learners to improve their listening comprehension through interactive audio playback with transcript support.

## Features

### Core Features
- **Audio Library Management**: Import audio files with optional transcripts (SRT/VTT format)
- **Sentence-Level Control**: Navigate and play individual sentences from transcripts
- **Multiple Playback Modes**:
  - Full Article Mode: Play the entire audio continuously
  - Single Sentence Mode: Focus on one sentence at a time with automatic looping
  - Bookmarked Only Mode: Play only your bookmarked sentences
- **Loop Playback**: Configure loop count (including infinite) and pause intervals
- **Bookmark System**: Mark important sentences for focused practice
- **Adjustable Playback Speed**: 0.5x to 2.0x speed control
- **Responsive UI**: Adaptive layout for mobile (iOS/Android) and desktop platforms

### Enhanced Features
- **Persistent Storage**: Audio library and settings saved locally
- **Visual Progress Bar**: Track playback position with seek capability
- **Current Sentence Highlighting**: Auto-scroll to currently playing sentence
- **Dark Mode Support**: System-aware theme switching
- **Professional UI**: Material Design 3 with polished animations

## Technology Stack

- **Flutter**: Cross-platform UI framework
- **just_audio**: Professional audio playback engine
- **subtitle**: Parse SRT/VTT transcript files
- **file_picker**: Import audio and transcript files
- **audio_video_progress_bar**: Interactive progress bar
- **provider**: State management
- **shared_preferences**: Local data persistence

## Architecture

```
lib/
├── models/              # Data models
│   ├── audio_item.dart       # Audio file metadata
│   ├── sentence.dart         # Transcript sentence data
│   └── playback_settings.dart # Playback configuration
├── providers/           # State management
│   ├── audio_library_provider.dart  # Library management
│   └── player_provider.dart         # Audio playback control
├── services/            # Business logic
│   ├── subtitle_parser.dart    # Parse transcript files
│   └── storage_service.dart    # Data persistence
├── screens/             # UI screens
│   ├── library_screen.dart     # Audio library view
│   └── player_screen.dart      # Audio player interface
├── widgets/             # Reusable components
│   ├── playback_controls.dart   # Play/pause/skip controls
│   ├── sentence_list_view.dart  # Transcript display
│   └── settings_panel.dart      # Playback settings
└── main.dart            # App entry point
```

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- iOS Simulator / Android Emulator / Physical device
- For desktop: macOS / Windows / Linux development setup

### Installation

1. Clone the repository
2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
# For mobile
flutter run

# For desktop
flutter run -d macos    # macOS
flutter run -d windows  # Windows
flutter run -d linux    # Linux
```

## Usage

### Adding Audio Files

1. Tap the **+** button in the Audio Library
2. Select an audio file (MP3, WAV, etc.)
3. Optionally select a transcript file (SRT or VTT format)
4. The audio will be added to your library

### Playback Controls

- **Play/Pause**: Control audio playback
- **Previous/Next**: Navigate between sentences
- **Stop**: Stop playback and reset
- **Progress Bar**: Tap to seek to specific position
- **Bookmark**: Tap ⭐ on any sentence to bookmark it

### Settings

Access settings via the ⚙️ icon to configure:
- **Playback Speed**: Adjust from 0.5x to 2.0x
- **Loop Playback**: Enable/disable with custom loop count
- **Pause Interval**: Set pause duration between loops (0-10 seconds)

### Playback Modes

Switch between modes in the player screen:
- **Full Article**: Listen to the complete audio
- **Single Sentence**: Focus on individual sentences with auto-repeat
- **Bookmarked Only**: Review your bookmarked sentences

## Transcript Format

The app supports standard subtitle formats:

**SRT Example:**
```
1
00:00:00,000 --> 00:00:03,000
Welcome to English listening practice.

2
00:00:03,500 --> 00:00:07,000
This is the second sentence.
```

**VTT Example:**
```
WEBVTT

00:00:00.000 --> 00:00:03.000
Welcome to English listening practice.

00:00:03.500 --> 00:00:07.000
This is the second sentence.
```

## Design Patterns & Best Practices

- **Provider Pattern**: Reactive state management with ChangeNotifier
- **Service Layer**: Separation of business logic from UI
- **Responsive Design**: LayoutBuilder for adaptive UI
- **Modular Architecture**: Clear separation of concerns
- **Error Handling**: Graceful fallbacks for missing data
- **Type Safety**: Full Dart null safety support

## Platform Support

- ✅ iOS
- ✅ Android
- ✅ macOS
- ✅ Windows
- ✅ Linux
- ✅ Web (with audio format limitations)

## Future Enhancements

Potential features for future versions:
- Cloud sync for library and bookmarks
- Speed adjustment with pitch correction
- AB repeat for specific segments
- Export bookmark lists
- Audio recording and comparison
- Dictionary integration
- Multiple language support

## License

This project is for educational and personal use.
