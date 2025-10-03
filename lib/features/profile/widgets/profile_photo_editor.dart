import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:recibos_flutter/core/services/profile_photo_service.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:recibos_flutter/core/utils/image_filter_utils.dart';

/// Instagram-style photo editor for profile pictures
/// Features: Crop (circular), Filters, Brightness adjustment
class ProfilePhotoEditor extends StatefulWidget {
  final File imageFile;
  final Function(Uint8List croppedImage, PhotoFilter filter) onSave;

  const ProfilePhotoEditor({
    super.key,
    required this.imageFile,
    required this.onSave,
  });

  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  final CropController _cropController = CropController();
  Uint8List? _imageBytes;
  Uint8List? _filteredBytes;
  PhotoFilter _selectedFilter = PhotoFilter.none;
  bool _isProcessing = false;
  int _currentStep = 0; // 0 = crop, 1 = filter

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  void _cropImage() {
    setState(() => _isProcessing = true);
    _cropController.cropCircle();
  }

  Future<void> _applyFilter(PhotoFilter filter) async {
    if (_imageBytes == null) return;

    setState(() {
      _isProcessing = true;
      _selectedFilter = filter;
    });

    // Apply filter to preview
    final filtered = await ImageFilterUtils.applyFilter(_imageBytes!, filter);

    setState(() {
      _filteredBytes = filtered;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _currentStep == 0 ? 'Crop Photo' : 'Apply Filter',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_currentStep == 0)
            TextButton(
              onPressed: _cropImage,
              child: const Text(
                'Next',
                style: TextStyle(
                  color: FlowColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () {
                      if (_filteredBytes != null) {
                        widget.onSave(_filteredBytes!, _selectedFilter);
                      }
                    },
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(FlowColors.primary),
                      ),
                    )
                  : const Text(
                      'Done',
                      style: TextStyle(
                        color: FlowColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _imageBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Preview area
                Expanded(
                  child: Center(
                    child: _currentStep == 0
                        ? _buildCropView()
                        : _buildFilterPreview(),
                  ),
                ),
                // Controls
                if (_currentStep == 1) _buildFilterSelector(),
              ],
            ),
    );
  }

  Widget _buildCropView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Crop(
        controller: _cropController,
        image: _imageBytes!,
        onCropped: (croppedData) {
          setState(() {
            _filteredBytes = croppedData;
            _currentStep = 1;
            _isProcessing = false;
          });
        },
        withCircleUi: true,
        baseColor: Colors.black,
        maskColor: Colors.black.withOpacity(0.7),
        radius: 20,
        onStatusChanged: (status) {
          // Handle crop status
        },
        initialSize: 0.8,
        fixCropRect: true,
        interactive: true,
        cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: FlowColors.primary),
      ),
    );
  }

  Widget _buildFilterPreview() {
    final displayBytes = _filteredBytes ?? _imageBytes!;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipOval(
            child: Image.memory(
              displayBytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSelector() {
    return Container(
      height: 120,
      color: Colors.black,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: PhotoFilter.values.length,
        itemBuilder: (context, index) {
          final filter = PhotoFilter.values[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () => _applyFilter(filter),
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? FlowColors.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: FutureBuilder<Uint8List>(
                        future: _getFilterThumbnail(filter),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(color: Colors.grey[900]);
                          }
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filter.displayName,
                    style: TextStyle(
                      color: isSelected ? FlowColors.primary : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Uint8List> _getFilterThumbnail(PhotoFilter filter) async {
    if (_imageBytes == null) return Uint8List(0);

    // Create a small thumbnail for filter preview
    return ImageFilterUtils.applyFilter(_imageBytes!, filter);
  }
}
