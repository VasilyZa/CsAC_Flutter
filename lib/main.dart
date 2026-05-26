import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/app_state.dart';
import 'src/l10n.dart';
import 'src/models.dart';
import 'src/preferences.dart';

part 'src/ui/app_shell.dart';
part 'src/ui/home.dart';
part 'src/ui/discovery.dart';
part 'src/ui/notifications.dart';
part 'src/ui/profile_settings.dart';
part 'src/ui/common_widgets.dart';
part 'src/ui/user_profile.dart';
part 'src/ui/conversation_detail.dart';
part 'src/ui/chat.dart';
part 'src/ui/media.dart';
part 'src/ui/helpers.dart';

void main() {
  runApp(const CsacMobileApp());
}

String appClientNameKey() {
  return Platform.isAndroid ? 'CsAC Mobile' : 'CsAC Desktop Client';
}
