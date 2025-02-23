import 'package:flutter/services.dart';

class ImageManager {
  static final ImageManager _instance = ImageManager._internal();
  factory ImageManager() => _instance;

  ImageManager._internal();

  Uint8List? logoImage;

  Future<void> loadLogo() async {
    final ByteData data = await rootBundle.load('assets/logoWithoutBg.png');
    logoImage = data.buffer.asUint8List();
  }
}