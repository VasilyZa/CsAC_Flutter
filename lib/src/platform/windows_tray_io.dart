import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

const _trayShowWindow = 'show_window';
const _trayHideWindow = 'hide_window';
const _trayExitApp = 'exit_app';

WindowsTrayController? _windowsTrayController;

Future<void> configureWindowsTray() async {
  if (!Platform.isWindows || _windowsTrayController != null) {
    return;
  }
  final controller = WindowsTrayController();
  _windowsTrayController = controller;
  await controller.initialize();
}

class WindowsTrayController with TrayListener, WindowListener {
  bool exiting = false;

  Future<void> initialize() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    await windowManager.setPreventClose(true);
    await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    await trayManager.setToolTip('CsAC');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _trayShowWindow, label: 'Show window'),
          MenuItem(key: _trayHideWindow, label: 'Hide to tray'),
          MenuItem.separator(),
          MenuItem(key: _trayExitApp, label: 'Exit CsAC'),
        ],
      ),
    );
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  Future<void> exitApp() async {
    exiting = true;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (err, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to destroy Windows tray: $err');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _trayShowWindow:
        unawaited(showWindow());
        break;
      case _trayHideWindow:
        unawaited(hideWindow());
        break;
      case _trayExitApp:
        unawaited(exitApp());
        break;
    }
  }

  @override
  void onWindowClose() {
    if (exiting) {
      return;
    }
    unawaited(hideWindow());
  }
}
