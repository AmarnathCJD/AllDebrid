import 'package:flutter/material.dart';

import '../providers/app_provider.dart';
import '../services/imdb_service.dart';
import '../widgets/widgets.dart';

Future<bool> toggleWatchlistWithFeedback(
  BuildContext context,
  AppProvider provider,
  ImdbSearchResult item, {
  bool? wasInWatchlist,
}) async {
  final existed = wasInWatchlist ?? provider.isInWatchlist(item.id);
  await provider.toggleWatchlist(item);

  if (context.mounted) {
    showAppSnackBar(
      context,
      existed ? 'Removed from watchlist' : 'Added to watchlist',
      type: existed ? AppFeedbackType.info : AppFeedbackType.success,
    );
  }

  return !existed;
}

Future<bool> addToWatchlistIfMissing(
  BuildContext context,
  AppProvider provider,
  ImdbSearchResult item,
) async {
  final existed = provider.isInWatchlist(item.id);
  if (existed) {
    return false;
  }

  await provider.toggleWatchlist(item);
  if (context.mounted) {
    showAppSnackBar(
      context,
      'Added to watchlist',
      type: AppFeedbackType.success,
    );
  }
  return true;
}
