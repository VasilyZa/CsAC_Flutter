import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

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

bool get supportsCustomDesktopWindowChrome =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> configureDesktopWindowChrome() async {
  if (!supportsCustomDesktopWindowChrome) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.setAsFrameless();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      minimumSize: Size(900, 620),
      backgroundColor: Color(0x00000000),
      title: 'CsAC',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

Widget buildDesktopWindowMoveArea({required Widget child}) {
  if (!supportsCustomDesktopWindowChrome) {
    return child;
  }
  return DragToMoveArea(child: child);
}

Widget buildDesktopWindowResizeFrame({
  required Widget child,
  bool enabled = true,
}) {
  if (!supportsCustomDesktopWindowChrome) {
    return child;
  }
  return DragToResizeArea(
    resizeEdgeSize: 6,
    enableResizeEdges: enabled ? null : const <ResizeEdge>[],
    child: child,
  );
}

Widget buildDesktopWindowStateListener({
  required Widget Function(BuildContext context, DesktopWindowFrameState state)
  builder,
}) {
  if (!supportsCustomDesktopWindowChrome) {
    return Builder(
      builder: (context) => builder(context, const DesktopWindowFrameState()),
    );
  }
  return _DesktopWindowStateListener(builder: builder);
}

class _DesktopWindowStateListener extends StatefulWidget {
  const _DesktopWindowStateListener({required this.builder});

  final Widget Function(BuildContext context, DesktopWindowFrameState state)
  builder;

  @override
  State<_DesktopWindowStateListener> createState() =>
      _DesktopWindowStateListenerState();
}

class _DesktopWindowStateListenerState
    extends State<_DesktopWindowStateListener>
    with WindowListener {
  DesktopWindowFrameState frameState = const DesktopWindowFrameState();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(refreshState());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> refreshState() async {
    if (!supportsCustomDesktopWindowChrome) {
      return;
    }
    final next = DesktopWindowFrameState(
      isFocused: await windowManager.isFocused(),
      isMaximized: await windowManager.isMaximized(),
      isFullScreen: await windowManager.isFullScreen(),
    );
    if (mounted) {
      setState(() => frameState = next);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, frameState);

  @override
  void onWindowFocus() => unawaited(refreshState());

  @override
  void onWindowBlur() => unawaited(refreshState());

  @override
  void onWindowMaximize() => unawaited(refreshState());

  @override
  void onWindowUnmaximize() => unawaited(refreshState());

  @override
  void onWindowEnterFullScreen() => unawaited(refreshState());

  @override
  void onWindowLeaveFullScreen() => unawaited(refreshState());

  @override
  void onWindowRestore() => unawaited(refreshState());
}

Future<bool> isDesktopWindowMaximized() async {
  if (!supportsCustomDesktopWindowChrome) {
    return false;
  }
  return windowManager.isMaximized();
}

Future<void> minimizeDesktopWindow() async {
  if (!supportsCustomDesktopWindowChrome) {
    return;
  }
  await windowManager.minimize();
}

Future<void> toggleMaximizeDesktopWindow() async {
  if (!supportsCustomDesktopWindowChrome) {
    return;
  }
  final isMaximized = await windowManager.isMaximized();
  if (isMaximized) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

Future<void> closeDesktopWindow() async {
  if (!supportsCustomDesktopWindowChrome) {
    return;
  }
  await windowManager.close();
}
