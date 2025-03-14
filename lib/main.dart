import 'package:flutter/material.dart';
import 'models/track.dart';
import 'models/folder.dart';
import 'db/database_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:flutter/services.dart';

void main() {
  runApp(const MusicLibraryApp());
}

class MusicLibraryApp extends StatelessWidget {
  const MusicLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Library',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: const FolderListScreen(),
    );
  }
}

// Экран списка папок
class FolderListScreen extends StatefulWidget {
  const FolderListScreen({super.key});

  @override
  _FolderListScreenState createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  late Future<List<Folder>> _foldersFuture;

  @override
  void initState() {
    super.initState();
    _refreshFolders();
  }

  void _refreshFolders() {
    setState(() {
      _foldersFuture = DatabaseHelper.instance.getFolders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
      ),
      body: FutureBuilder<List<Folder>>(
        future: _foldersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No folders found'));
          }

          final folders = snapshot.data!;
          return ListView.builder(
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(folder.name),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackListScreen(folder: folder),
                      ),
                    ).then((_) => _refreshFolders());
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFolderDialog(context),
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Folder Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.instance.insertFolder(Folder(name: name));
                Navigator.pop(context);
                _refreshFolders();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Экран списка треков
class TrackListScreen extends StatefulWidget {
  final Folder folder;

  const TrackListScreen({super.key, required this.folder});

  @override
  _TrackListScreenState createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  late Future<List<Track>> _tracksFuture;
  final _player = AudioPlayer(); // Плеер для аудио

  @override
  void initState() {
    super.initState();
    _refreshTracks();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _refreshTracks() {
    setState(() {
      _tracksFuture = DatabaseHelper.instance.getTracks(folderId: widget.folder.id);
    });
  }

  Future<void> _playTrack(Track track) async {
    if (track.filePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(track: track),
        ),
      );
    } else {
      debugPrint('No audio file selected for this track');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio file available')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
      ),
      body: FutureBuilder<List<Track>>(
        future: _tracksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tracks found'));
          }

          final tracks = snapshot.data!;
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(track.title),
                  subtitle: Text('${track.artist} - ${track.duration ~/ 60}:${(track.duration % 60).toString().padLeft(2, '0')}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (track.filePath != null)
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => _playTrack(track),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditTrackScreen(track: track),
                            ),
                          );
                          if (result == true) {
                            _refreshTracks();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTrackScreen(folder: widget.folder)),
          );
          if (result == true) {
            _refreshTracks();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Экран добавления трека
class AddTrackScreen extends StatefulWidget {
  final Folder folder;

  const AddTrackScreen({super.key, required this.folder});

  @override
  _AddTrackScreenState createState() => _AddTrackScreenState();
}

class _AddTrackScreenState extends State<AddTrackScreen> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _durationController = TextEditingController();
  String? _filePath;
  final _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _durationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _filePath = path;
      });
      
      // Получаем длительность аудиофайла
      try {
        await _audioPlayer.setFilePath(path);
        final duration = await _audioPlayer.duration;
        if (duration != null) {
          setState(() {
            _durationController.text = duration.inSeconds.toString();
          });
          debugPrint('Audio duration: ${duration.inSeconds} seconds');
        }
      } catch (e) {
        debugPrint('Error getting audio duration: $e');
      }
      
      debugPrint('Selected audio file: $_filePath');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Track'),
        actions: [
          TextButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              final artist = _artistController.text.trim();
              final durationText = _durationController.text.trim();

              if (title.isNotEmpty && artist.isNotEmpty && durationText.isNotEmpty) {
                final track = Track(
                  title: title,
                  artist: artist,
                  duration: int.tryParse(durationText) ?? 0,
                  filePath: _filePath,
                  folderId: widget.folder.id,
                );
                await DatabaseHelper.instance.insertTrack(track);
                if (mounted) {
                  Navigator.pop(context, true);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artist'),
            ),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (seconds)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickAudioFile,
              child: const Text('Pick Audio File'),
            ),
            if (_filePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Selected: ${_filePath!.split('/').last}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Экран редактирования трека
class EditTrackScreen extends StatefulWidget {
  final Track track;

  const EditTrackScreen({super.key, required this.track});

  @override
  _EditTrackScreenState createState() => _EditTrackScreenState();
}

class _EditTrackScreenState extends State<EditTrackScreen> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _durationController;
  String? _filePath;
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artist);
    _durationController = TextEditingController(text: widget.track.duration.toString());
    _filePath = widget.track.filePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _durationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _filePath = path;
      });
      
      // Получаем длительность аудиофайла
      try {
        await _audioPlayer.setFilePath(path);
        final duration = await _audioPlayer.duration;
        if (duration != null) {
          setState(() {
            _durationController.text = duration.inSeconds.toString();
          });
          debugPrint('Audio duration: ${duration.inSeconds} seconds');
        }
      } catch (e) {
        debugPrint('Error getting audio duration: $e');
      }
      
      debugPrint('Selected audio file: $_filePath');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Track'),
        actions: [
          TextButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              final artist = _artistController.text.trim();
              final durationText = _durationController.text.trim();

              if (title.isNotEmpty && artist.isNotEmpty && durationText.isNotEmpty) {
                final updatedTrack = Track(
                  id: widget.track.id,
                  title: title,
                  artist: artist,
                  duration: int.tryParse(durationText) ?? 0,
                  filePath: _filePath,
                  folderId: widget.track.folderId,
                );
                await DatabaseHelper.instance.updateTrack(updatedTrack);
                if (mounted) {
                  Navigator.pop(context, true);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artist'),
            ),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (seconds)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickAudioFile,
              child: const Text('Pick Audio File'),
            ),
            if (_filePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Selected: ${_filePath!.split('/').last}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Экран аудио плеера
class AudioPlayerScreen extends StatefulWidget {
  final Track track;

  const AudioPlayerScreen({super.key, required this.track});

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    // Инициализация слушателей событий
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // Загрузка и воспроизведение трека
    try {
      await _player.setFilePath(widget.track.filePath!);
      await _player.play();
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing track: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Информация о треке
            Text(
              widget.track.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.track.artist,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Слайдер для перемотки
            Slider(
              min: 0,
              max: _duration.inSeconds.toDouble(),
              value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
              onChanged: (value) {
                final position = Duration(seconds: value.toInt());
                _player.seek(position);
              },
            ),
            
            // Отображение времени
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position)),
                  Text(_formatDuration(_duration)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Кнопки управления
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Перемотка назад на 10 секунд
                IconButton(
                  iconSize: 48,
                  icon: const Icon(Icons.replay_10),
                  onPressed: () {
                    final newPosition = Duration(
                      seconds: (_position.inSeconds - 10).clamp(0, _duration.inSeconds),
                    );
                    _player.seek(newPosition);
                  },
                ),
                
                const SizedBox(width: 16),
                
                // Кнопка воспроизведения/паузы
                IconButton(
                  iconSize: 64,
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: () {
                    if (_isPlaying) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                ),
                
                const SizedBox(width: 16),
                
                // Перемотка вперед на 10 секунд
                IconButton(
                  iconSize: 48,
                  icon: const Icon(Icons.forward_10),
                  onPressed: () {
                    final newPosition = Duration(
                      seconds: (_position.inSeconds + 10).clamp(0, _duration.inSeconds),
                    );
                    _player.seek(newPosition);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}