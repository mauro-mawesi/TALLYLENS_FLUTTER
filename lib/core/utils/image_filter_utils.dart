import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:recibos_flutter/core/services/profile_photo_service.dart';

/// Utility class for applying image filters without API dependencies
class ImageFilterUtils {
  /// Apply filter to image bytes
  static Future<Uint8List> applyFilter(Uint8List imageBytes, PhotoFilter filter) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    img.Image filtered;
    switch (filter) {
      case PhotoFilter.none:
        filtered = image;
        break;
      case PhotoFilter.grayscale:
        filtered = img.grayscale(image);
        break;
      case PhotoFilter.sepia:
        filtered = img.sepia(image);
        break;
      case PhotoFilter.invert:
        filtered = img.invert(image);
        break;
      case PhotoFilter.brighten:
        filtered = img.adjustColor(image, brightness: 1.2);
        break;
      case PhotoFilter.darken:
        filtered = img.adjustColor(image, brightness: 0.8);
        break;
      case PhotoFilter.contrast:
        filtered = img.adjustColor(image, contrast: 1.3);
        break;
      case PhotoFilter.saturate:
        filtered = img.adjustColor(image, saturation: 1.5);
        break;
      case PhotoFilter.vignette:
        filtered = img.vignette(image);
        break;
    }

    return Uint8List.fromList(img.encodeJpg(filtered, quality: 90));
  }

  /// Crop image to circular shape
  static Future<Uint8List> cropToCircle(Uint8List imageBytes, int size) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize to square
    final square = img.copyResizeCropSquare(image, size: size);

    // Create circular mask
    final circular = img.copyCropCircle(square);

    return Uint8List.fromList(img.encodePng(circular));
  }
}
