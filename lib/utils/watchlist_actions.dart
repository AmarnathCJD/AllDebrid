import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_provider.dart';
import '../services/imdb_service.dart';
import '../widgets/widgets.dart';

Future<bool> toggleWatchlistWithFeedback(
  BuildContext context,
  WidgetRef ref,
  AppState appState,
  ImdbSearchResult item, {
  bool? wasInWatchlist,
}) async {
  final existed = wasInWatchlist ?? appState.isInWatchlist(item.id);
  await ref.read(appNotifierProvider.notifier).toggleWatchlist(item);

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
  WidgetRef ref,
  AppState appState,
  ImdbSearchResult item,
) async {
  final existed = appState.isInWatchlist(item.id);
  if (existed) {
    return false;
  }

  await ref.read(appNotifierProvider.notifier).toggleWatchlist(item);
  if (context.mounted) {
    showAppSnackBar(
      context,
      'Added to watchlist',
      type: AppFeedbackType.success,
    );
  }
  return true;
}
