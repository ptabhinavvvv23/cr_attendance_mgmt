import 'package:flutter/widgets.dart';

import 'repository_container.dart';

/// InheritedWidget providing [RepositoryContainer] down the widget tree.
/// Follows the established pure-Flutter dependency management pattern used by
/// [ThemeControllerProvider], avoiding third-party state or DI package lock-in.
class RepositoryProvider extends InheritedWidget {
  final RepositoryContainer container;

  const RepositoryProvider({
    super.key,
    required this.container,
    required super.child,
  });

  /// Accesses the nearest [RepositoryContainer] in the widget tree.
  static RepositoryContainer of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<RepositoryProvider>();
    assert(
      provider != null,
      'No RepositoryProvider found in context. Ensure RepositoryProvider is placed near the app root.',
    );
    return provider!.container;
  }

  /// Optional accessor returning null if not found.
  static RepositoryContainer? maybeOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<RepositoryProvider>();
    return provider?.container;
  }

  @override
  bool updateShouldNotify(RepositoryProvider oldWidget) {
    return container != oldWidget.container;
  }
}
