import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:recibos_flutter/core/utils/image_filter_utils.dart';

/// Service for handling profile photo operations with Instagram-like editing
class ProfilePhotoService {
  final ApiService _apiService;
  final ImagePicker _picker = ImagePicker();

  ProfilePhotoService({required ApiService apiService}) : _apiService = apiService;

  /// Pick image from gallery or camera
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Apply filter to image (delegates to ImageFilterUtils)
  Future<Uint8List> applyFilter(Uint8List imageBytes, PhotoFilter filter) async {
    return ImageFilterUtils.applyFilter(imageBytes, filter);
  }

  /// Crop image to circular shape (delegates to ImageFilterUtils)
  Future<Uint8List> cropToCircle(Uint8List imageBytes, int size) async {
    return ImageFilterUtils.cropToCircle(imageBytes, size);
  }

  /// Compress and optimize image for upload
  Future<File> compressImage(File imageFile, {int quality = 85}) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize if too large
    final resized = img.copyResize(
      image,
      width: image.width > 1080 ? 1080 : image.width,
      height: image.height > 1080 ? 1080 : image.height,
    );

    // Encode with quality
    final compressed = img.encodeJpg(resized, quality: quality);

    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(compressed);

    return tempFile;
  }

  /// Upload profile photo to server
  Future<String> uploadProfilePhoto(File imageFile) async {
    try {
      // First compress the image
      final compressed = await compressImage(imageFile);

      // Upload using existing upload endpoint
      final response = await _apiService.uploadImageWithResponse(compressed);

      // Try different possible keys for image URL
      final imageUrl = response['imageUrl'] ??
                      response['image_url'] ??
                      response['data']?['imageUrl'] ??
                      response['data']?['image_url'];

      if (imageUrl == null) {
        throw Exception('No imageUrl in response');
      }

      return imageUrl as String;
    } catch (e) {
      throw Exception('Failed to upload profile photo: $e');
    }
  }

  /// Update profile photo in backend
  Future<void> updateProfilePhoto(String imageUrl) async {
    await _apiService.updateProfilePhoto(imageUrl);
  }

  /// Delete profile photo
  Future<void> deleteProfilePhoto() async {
    await _apiService.deleteProfilePhoto();
  }

  /// Complete flow: pick, edit, upload and update
  Future<String?> pickAndUploadProfilePhoto({
    required ImageSource source,
    PhotoFilter? filter,
    bool cropCircular = true,
  }) async {
    try {
      // 1. Pick image
      final pickedFile = await pickImage(source: source);
      if (pickedFile == null) return null;

      // 2. Read bytes
      Uint8List imageBytes = await pickedFile.readAsBytes();

      // 3. Apply filter if specified
      if (filter != null && filter != PhotoFilter.none) {
        imageBytes = await applyFilter(imageBytes, filter);
      }

      // 4. Crop to circle if needed
      if (cropCircular) {
        imageBytes = await cropToCircle(imageBytes, 512);
      }

      // 5. Save processed image to temp file
      final tempDir = await getTemporaryDirectory();
      final processedFile = File(
        '${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await processedFile.writeAsBytes(imageBytes);

      // 6. Upload
      final imageUrl = await uploadProfilePhoto(processedFile);

      // 7. Update in backend
      await updateProfilePhoto(imageUrl);

      return imageUrl;
    } catch (e) {
      throw Exception('Failed to complete profile photo upload: $e');
    }
  }
}

/// Available photo filters
enum PhotoFilter {
  none,
  grayscale,
  sepia,
  invert,
  brighten,
  darken,
  contrast,
  saturate,
  vignette,
}

/// Extension to get filter display name
extension PhotoFilterExtension on PhotoFilter {
  String get displayName {
    switch (this) {
      case PhotoFilter.none:
        return 'Original';
      case PhotoFilter.grayscale:
        return 'B&W';
      case PhotoFilter.sepia:
        return 'Sepia';
      case PhotoFilter.invert:
        return 'Invert';
      case PhotoFilter.brighten:
        return 'Bright';
      case PhotoFilter.darken:
        return 'Dark';
      case PhotoFilter.contrast:
        return 'Contrast';
      case PhotoFilter.saturate:
        return 'Vibrant';
      case PhotoFilter.vignette:
        return 'Vignette';
    }
  }
}
