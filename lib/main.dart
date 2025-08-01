import 'package:flutter/material.dart';
import 'package:streameasy/main_mobile.dart';
import 'package:streameasy/main_server.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    runApp(const ServerApp());
  } else {
    runApp(const MobileApp());
  }
}
