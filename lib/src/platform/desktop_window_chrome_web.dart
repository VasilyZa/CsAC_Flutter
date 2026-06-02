import 'package:flutter/widgets.dart';

class DesktopWindowFrameState {
  const DesktopWindowFrameState({
    this.isFocused = true,
    this.isMaximized = false,
    this.isFullScreen = false,
  });

  final bool isFocused;
  final bool isMaximized;
  final bool isFullScreen;

  bool get isExpanded => isMaximized || isFullScreen;
}

bool get supportsCustomDesktopWindowChrome => false;

Future<void> configureDesktopWindowChrome() async {}

Widget buildDesktopWindowMoveArea({required Widget child}) => child;

Widget buildDesktopWindowResizeFrame({
  required Widget child,
  bool enabled = true,
}) => child;

Widget buildDesktopWindowStateListener({
  required Widget Function(BuildContext context, DesktopWindowFrameState state)
  builder,
}) {
  return Builder(
    builder: (context) => builder(context, const DesktopWindowFrameState()),
  );
}

Future<bool> isDesktopWindowMaximized() async => false;

Future<void> minimizeDesktopWindow() async {}

Future<void> toggleMaximizeDesktopWindow() async {}

Future<void> closeDesktopWindow() async {}
