import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

const desktopWindowDefaultMinimumSize = Size(900, 620);
const desktopWindowMobilePreviewWidth = 430.0;
const desktopWindowMobilePreviewMinimumSize = Size(
  desktopWindowMobilePreviewWidth,
  620,
);
const desktopWindowMobilePreviewMaximumSize = Size(
  desktopWindowMobilePreviewWidth,
  100000,
);
const _desktopWindowUnrestrictedMaximumSize = Size(100000, 100000);

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

Future<void> configureDesktopWindowChrome({
  bool forceMobileWidth = false,
}) async {
  if (!supportsCustomDesktopWindowChrome) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.setAsFrameless();
  final minimumSize = forceMobileWidth
      ? desktopWindowMobilePreviewMinimumSize
      : desktopWindowDefaultMinimumSize;
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: forceMobileWidth ? desktopWindowMobilePreviewMinimumSize : null,
      minimumSize: minimumSize,
      maximumSize: forceMobileWidth
          ? desktopWindowMobilePreviewMaximumSize
          : null,
      backgroundColor: Color(0x00000000),
      title: 'CsAC',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

Future<void> applyDesktopWindowMobileWidth(bool enabled) async {
  if (!supportsCustomDesktopWindowChrome) {
    return;
  }
  await windowManager.ensureInitialized();
  if (await windowManager.isFullScreen()) {
    await windowManager.setFullScreen(false);
  }
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  }
  if (enabled) {
    final current = await windowManager.getSize();
    final nextHeight = current.height
        .clamp(desktopWindowMobilePreviewMinimumSize.height, double.infinity)
        .toDouble();
    await windowManager.setMinimumSize(desktopWindowMobilePreviewMinimumSize);
    await windowManager.setMaximumSize(desktopWindowMobilePreviewMaximumSize);
    await windowManager.setSize(
      Size(desktopWindowMobilePreviewWidth, nextHeight),
    );
    return;
  }
  await windowManager.setMaximumSize(_desktopWindowUnrestrictedMaximumSize);
  await windowManager.setMinimumSize(desktopWindowDefaultMinimumSize);
  final current = await windowManager.getSize();
  if (current.width < desktopWindowDefaultMinimumSize.width ||
      current.height < desktopWindowDefaultMinimumSize.height) {
    await windowManager.setSize(
      Size(
        current.width < desktopWindowDefaultMinimumSize.width
            ? desktopWindowDefaultMinimumSize.width
            : current.width,
        current.height < desktopWindowDefaultMinimumSize.height
            ? desktopWindowDefaultMinimumSize.height
            : current.height,
      ),
    );
  }
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
