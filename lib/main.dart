import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/app_state.dart';
import 'src/api_client.dart';
import 'src/l10n.dart';
import 'src/models.dart';
import 'src/notification_service.dart';
import 'src/platform/chat_export_writer.dart';
import 'src/platform/platform_support.dart';
import 'src/preferences.dart';
import 'src/update_checker.dart';

part 'src/ui/app_shell.dart';
part 'src/ui/home.dart';
part 'src/ui/discovery.dart';
part 'src/ui/notifications.dart';
part 'src/ui/profile_settings.dart';
part 'src/ui/common_widgets.dart';
part 'src/ui/command_palette.dart';
part 'src/ui/app_lock.dart';
part 'src/ui/user_profile.dart';
part 'src/ui/conversation_detail.dart';
part 'src/ui/chat.dart';
part 'src/ui/chat_export.dart';
part 'src/ui/media.dart';
part 'src/ui/conversation_media.dart';
part 'src/ui/helpers.dart';

void main() {
  runApp(const CsacMobileApp());
}
