import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (state != index) {
      state = index;
    }
  }
}

final navigationNotifierProvider = NotifierProvider<NavigationNotifier, int>(() {
  return NavigationNotifier();
});
