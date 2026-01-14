import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/common_widgets.dart';

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  Directory? _currentDir;
  List<FileSystemEntity> _entities = [];
  bool _isLoading = true;
  String _initialPath = '';
  int _totalAppSize = 0;

  // Fake total disk for demo as we can't reliably get full disk stats without plugins
  // But we can show 'App Usage' nicely.

  @override
  void initState() {
    super.initState();
    _initDirectory();
  }

  Future<void> _initDirectory() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        _initialPath = '${dir.path}/AllDebrid/Downloads';
        _currentDir = Directory(_initialPath);
        if (!await _currentDir!.exists()) {
          await _currentDir!.create(recursive: true);
        }
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _initialPath = '${dir.path}/Downloads';
      _currentDir = Directory(_initialPath);
      if (!await _currentDir!.exists()) {
        await _currentDir!.create(recursive: true);
      }
    }
    await _loadDirectory();
    _calculateAppUsage();
  }

  Future<void> _calculateAppUsage() async {
    try {
      // Deep scan for size
      final root = Directory(_initialPath);
      if (await root.exists()) {
        int size = 0;
        await for (var entity
            in root.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            size += await entity.length();
          }
        }
        if (mounted) setState(() => _totalAppSize = size);
      }
    } catch (_) {}
  }

  Future<void> _loadDirectory() async {
    if (_currentDir == null) return;

    setState(() => _isLoading = true);

    try {
      final entities = await _currentDir!.list().toList();
      entities.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      _entities = entities;
    } catch (e) {
      _entities = [];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _navigateBack() async {
    if (_currentDir == null || _currentDir!.path == _initialPath) return;

    setState(() {
      _currentDir = _currentDir!.parent;
    });
    await _loadDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStats(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Usage Card (Compact & reduced glow)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.7)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.sd_storage_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('APP USAGE',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    Text(formatBytes(_totalAppSize),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('RECENT FILES',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMuted,
                letterSpacing: 1.5)),
        const SizedBox(height: 10),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHeader() {
    final isRoot = _currentDir?.path == _initialPath;
    final currentFolderName =
        _currentDir?.path.split(Platform.pathSeparator).last ?? 'Files';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isRoot)
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _navigateBack,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: AppTheme.textPrimary),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BROWSE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 1.5)),
                Text(isRoot ? 'FILES' : currentFolderName.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1,
                        color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _loadDirectory();
                _calculateAppUsage();
              },
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 20, color: AppTheme.primaryColor),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 6,
        itemBuilder: (_, __) => const SkeletonCard(height: 70),
      );
    }

    if (_entities.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open_rounded,
        title: 'Empty Directory',
        subtitle: 'No files found in this location',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _entities.length,
      itemBuilder: (context, index) {
        final entity = _entities[index];
        final isDirectory = entity is Directory;
        final name = entity.path.split(Platform.pathSeparator).last;

        return _buildFileItem(entity, isDirectory, name, index);
      },
    );
  }

  Widget _buildFileItem(
      FileSystemEntity entity, bool isDirectory, String name, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDirectory) {
              setState(() => _currentDir = entity as Directory);
              _loadDirectory();
            } else {
              OpenFilex.open(entity.path);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDirectory
                            ? [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withOpacity(0.6)
                              ]
                            : [
                                AppTheme.surfaceColor,
                                AppTheme.backgroundColor
                              ]),
                    borderRadius: BorderRadius.circular(14),
                    border: isDirectory
                        ? null
                        : Border.all(color: AppTheme.borderColor),
                  ),
                  child: Icon(
                    isDirectory ? Icons.folder_rounded : _getFileIcon(name),
                    color: isDirectory ? Colors.white : AppTheme.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (!isDirectory)
                        FutureBuilder<int>(
                          future: (entity as File).length(),
                          builder: (context, snapshot) => Text(
                            formatBytes(snapshot.data ?? 0),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500),
                          ),
                        )
                      else
                        const Text('Folder',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppTheme.textMuted, size: 20),
                  color: AppTheme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    if (!isDirectory)
                      const PopupMenuItem(
                          value: 'open',
                          child: Row(children: [
                            Icon(Icons.open_in_new_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Open')
                          ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppTheme.errorColor),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: AppTheme.errorColor))
                        ])),
                  ],
                  onSelected: (value) async {
                    if (value == 'open') {
                      final result = await OpenFilex.open(entity.path);
                      if (result.type != ResultType.done) {
                        Fluttertoast.showToast(msg: "Could not open file");
                      }
                    } else if (value == 'delete') {
                      _confirmDelete(entity);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms, delay: (20 * index).ms)
        .slideX(begin: 0.1, end: 0);
  }

  void _confirmDelete(FileSystemEntity entity) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 32, color: AppTheme.errorColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Item?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to permanently delete "${entity.path.split(Platform.pathSeparator).last}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await entity.delete(recursive: true);
                          Navigator.pop(context);
                          _loadDirectory();
                          _calculateAppUsage();
                        } catch (e) {
                          Navigator.pop(context);
                          Fluttertoast.showToast(msg: "Error deleting");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('DELETE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.movie_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audiotrack_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded; // Better icon
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
