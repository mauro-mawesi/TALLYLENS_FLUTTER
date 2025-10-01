import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:recibos_flutter/core/services/lock_bridge.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickFromGallery() async {
    LockBridge.suppressOnce();
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    return picked != null ? File(picked.path) : null;
  }

  Future<File?> pickFromCamera() async {
    LockBridge.suppressOnce();
    final picked = await _picker.pickImage(source: ImageSource.camera);
    return picked != null ? File(picked.path) : null;
  }
}
