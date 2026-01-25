import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/imdb_service.dart';
import '../../services/torrent_scraper_service.dart';
import '../../models/torrent.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class MediaInfoScreen extends StatefulWidget {
  final ImdbSearchResult item;

  const MediaInfoScreen({super.key, required this.item});

  @override
  State<MediaInfoScreen> createState() => _MediaInfoScreenState();
}

class _MediaInfoScreenState extends State<MediaInfoScreen> {
  final ImdbService _imdbService = ImdbService();
  final TorrentScraperService _scraper = TorrentScraperService();

  late ImdbSearchResult _item;
  List<TorrentEntry> _torrentResults = [];
  bool _loadingTorrents = true;
  int? _selectedSeason;
  int? _selectedEpisode;

  @override
  void initState() {
    super.initState();
    _item = _upgradeImageQuality(widget.item);
    _loadDetails();
    _search();
  }

  // Upgrade TMDB image URLs to original quality
  ImdbSearchResult _upgradeImageQuality(ImdbSearchResult item) {
    String posterUrl = item.posterUrl;

    // Check if it's a TMDB URL
    if (posterUrl.contains('image.tmdb.org/t/p/')) {
      // Replace size (w220_and_h330_face, w500, etc) with 'original'
      posterUrl = posterUrl.replaceAllMapped(
        RegExp(r'/t/p/[^/]+/'),
        (match) => '/t/p/original/',
      );
    }

    return item.copyWith(posterUrl: posterUrl);
  }

  Future<void> _loadDetails() async {
    try {
      final details = await _imdbService.fetchDetails(widget.item.id);
      if (mounted) {
        setState(() {
          _item = _upgradeImageQuality(widget.item.copyWith(
            kind: details.kind ?? widget.item.kind,
            rating: widget.item.rating ?? details.rating,
            description: widget.item.description ?? details.description,
            posterUrl: widget.item.posterUrl.isNotEmpty
                ? widget.item.posterUrl
                : details.posterUrl,
            year: widget.item.year.isNotEmpty ? widget.item.year : details.year,
          ));
        });
      }
    } catch (e) {
      print('Error loading details: $e');
    }
  }

  Future<void> _search() async {
    try {
      final query = '${_item.title} ${_item.year}'.trim();
      final results = await _scraper.search(query);
      if (mounted) {
        setState(() {
          _torrentResults = results;
          _loadingTorrents = false;
        });
      }
    } catch (e) {
      print('Error searching torrents: $e');
      if (mounted) {
        setState(() => _loadingTorrents = false);
      }
    }
  }

  bool get _isTvShow {
    final kind = _item.kind?.toLowerCase();
    return kind == 'tvseries' ||
        kind == 'tv series' ||
        kind == 'series' ||
        kind == 'tvepisode';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar with poster background
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            backgroundColor: AppTheme.cardColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Top margin spacer
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.backgroundColor,
                            AppTheme.backgroundColor.withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Poster image
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: CachedNetworkImage(
                      imageUrl: _item.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.cardColor,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.cardColor,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 64, color: Colors.white30),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.8),
                          AppTheme.backgroundColor,
                        ],
                        stops: const [0.0, 0.4, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Title and details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Year, Rating, Type
                  Row(
                    children: [
                      if (_item.year.isNotEmpty)
                        Text(
                          _item.year,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      if (_item.year.isNotEmpty) const SizedBox(width: 12),
                      if (_item.rating != null)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${_item.rating}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      if (_item.rating != null) const SizedBox(width: 12),
                      Text(
                        _isTvShow ? 'TV Series' : 'Movie',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (_item.description != null &&
                      _item.description!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.description!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Season/Episode selector for TV shows
                  if (_isTvShow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Episode (Optional)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Season',
                                  hintStyle: const TextStyle(
                                    color: AppTheme.textMuted,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSeason = int.tryParse(val);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Episode',
                                  hintStyle: const TextStyle(
                                    color: AppTheme.textMuted,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedEpisode = int.tryParse(val);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Torrents Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Icon(Icons.download_rounded,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Available Downloads',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_loadingTorrents)
            SliverToBoxAdapter(
              child: Container(
                height: 200,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          else if (_torrentResults.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                height: 150,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No torrents found',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTorrentCard(
                  _torrentResults[index],
                  index,
                ),
                childCount: _torrentResults.length,
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildTorrentCard(TorrentEntry torrent, int index) {
    return GestureDetector(
      onTap: () => _addMagnet(torrent),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardColor.withOpacity(0.8),
              AppTheme.cardColor.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          // border: Border.all(
          //   color: AppTheme.primaryColor.withOpacity(0.2),
          //   width: 1,
          // ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with wrap
            Text(
              torrent.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Details row
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                // Size
                if (torrent.size != null && torrent.size!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.storage_rounded,
                            size: 14, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        torrent.size!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                // Seeds
                if (torrent.seeders != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.trending_up_rounded,
                            size: 14, color: Colors.green),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${torrent.seeders}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                // Peers
                if (torrent.leechers != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.people_rounded,
                            size: 14, color: Colors.orange),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${torrent.leechers}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Add button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      const Text(
                        'ADD TO DOWNLOADS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMagnet(TorrentEntry torrent) async {
    try {
      String query = _item.title;
      if (_isTvShow && _selectedSeason != null && _selectedEpisode != null) {
        query =
            '$query S${_selectedSeason.toString().padLeft(2, '0')}E${_selectedEpisode.toString().padLeft(2, '0')}';
      }

      final magnetLink = torrent.url; // Use URL directly
      if (magnetLink.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract magnet link'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final magnet =
          await context.read<MagnetProvider>().uploadMagnet(magnetLink);

      // Auto-link magnet to this item in cache
      if (magnet != null) {
        await _imdbService.saveTrendingCache(
          [_item.copyWith(magnetId: magnet.id.toString())],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added & linked: ${torrent.title}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
