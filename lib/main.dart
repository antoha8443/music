import 'package:flutter/material.dart';
import 'models/track.dart';
import 'models/folder.dart';
import 'db/database_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';

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

  Future<void> _playTrack(String? filePath) async {
    if (filePath != null) {
      try {
        await _player.setFilePath(filePath);
        await _player.play();
        debugPrint('Playing: $filePath');
      } catch (e) {
        debugPrint('Error playing track: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing track: $e')),
          );
        }
      }
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
                  subtitle: Text('${track.artist} - ${track.duration ~/ 60}:${track.duration % 60}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (track.filePath != null)
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => _playTrack(track.filePath),
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

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
      });
      debugPrint('Selected audio file: $_filePath');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _durationController.dispose();
    super.dispose();
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artist);
    _durationController = TextEditingController(text: widget.track.duration.toString());
    _filePath = widget.track.filePath;
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
      });
      debugPrint('Selected audio file: $_filePath');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _durationController.dispose();
    super.dispose();
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