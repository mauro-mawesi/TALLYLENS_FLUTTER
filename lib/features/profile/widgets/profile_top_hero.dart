import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:recibos_flutter/core/services/profile_photo_service.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/features/profile/widgets/profile_photo_editor.dart';

class ProfileTopHero extends StatefulWidget {
  final String? email;
  const ProfileTopHero({super.key, this.email});

  @override
  State<ProfileTopHero> createState() => _ProfileTopHeroState();
}

class _ProfileTopHeroState extends State<ProfileTopHero> {
  String? _profileImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  void _loadProfileImage() {
    final user = sl<AuthService>().profile;
    setState(() {
      _profileImageUrl = user?.profileImageUrl;
    });
  }

  Future<void> _pickAndEditProfilePhoto(ImageSource source) async {
    try {
      final photoService = ProfilePhotoService(apiService: sl<ApiService>());
      final imageFile = await photoService.pickImage(source: source);

      if (imageFile == null || !mounted) return;

      // Show editor
      final result = await Navigator.of(context).push<(Uint8List, PhotoFilter)?>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ProfilePhotoEditor(
            imageFile: imageFile,
            onSave: (croppedImage, filter) {
              Navigator.of(context).pop((croppedImage, filter));
            },
          ),
        ),
      );

      if (result == null || !mounted) return;

      setState(() => _isUploading = true);

      // Save edited image to temp file
      final tempDir = await photoService.compressImage(imageFile);
      final editedFile = File('${tempDir.parent.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await editedFile.writeAsBytes(result.$1);

      // Upload and update
      final relativePath = await photoService.uploadProfilePhoto(editedFile);
      await photoService.updateProfilePhoto(relativePath);

      // Reload user profile to get the signed URL
      await sl<AuthService>().refreshProfile();

      if (mounted) {
        setState(() {
          _profileImageUrl = sl<AuthService>().profile?.profileImageUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndEditProfilePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndEditProfilePhoto(ImageSource.gallery);
              },
            ),
            if (_profileImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ProfilePhotoService(apiService: sl<ApiService>()).deleteProfilePhoto();
                    if (mounted) {
                      setState(() => _profileImageUrl = null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile photo removed')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = sl<AuthService>().displayName ?? '';
    final cs = Theme.of(context).colorScheme;
    // Pintamos los ornamentos detrás usando CustomPaint que se ajusta al tamaño del contenido.
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: CustomPaint(
        painter: _OrnamentsPainter(cs.primary.withOpacity(0.08)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            _AvatarRing(
              name: name,
              imageUrl: _profileImageUrl,
              isUploading: _isUploading,
              onTap: _showPhotoOptions,
            ),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: FlowColors.text(context),
                    fontSize: 24,
                  ),
            ),
            if ((widget.email ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.email!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 14),
            const _BadgesRow(),
            const SizedBox(height: 16),
            const _StatsRow(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onTap;

  const _AvatarRing({
    required this.name,
    this.imageUrl,
    this.isUploading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = (name.isNotEmpty ? name.trim()[0] : '?').toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF5A29A8), Color(0xFF45C677)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface.withOpacity(0.15),
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        key: ValueKey(imageUrl), // Preserva la imagen cuando el widget se reconstruye
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                        cacheHeight: 200,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          // Edit button overlay
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FlowColors.primary,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              child: isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesRow extends StatelessWidget {
  const _BadgesRow();
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          _Badge(icon: Icons.check_circle, label: t.badgeReceiptsDigitized('10')),
          _Badge(icon: Icons.savings_outlined, label: t.badgeMonthlyUnderControl),
          _Badge(icon: Icons.celebration_outlined, label: t.badgeFirstMonthUsing),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon; final String label;
  const _Badge({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withOpacity(0.12), border: Border.all(color: cs.primary.withOpacity(0.25))), child: Icon(icon, color: cs.primary, size: 20)),
      const SizedBox(height: 6),
      SizedBox(
        width: 100,
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FlowColors.text(context), fontSize: 11),
        ),
      )
    ]);
  }
}

class _StatsRow extends StatefulWidget {
  const _StatsRow();

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _statsFuture;
  Map<String, dynamic>? _cachedData;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _statsFuture = sl<ApiService>().getReceiptStats(days: 365);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final locale = Localizations.localeOf(context).toLanguageTag();
    final currency = NumberFormat.simpleCurrency(locale: locale);
    final t = AppLocalizations.of(context)!;
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snap) {
        // Cache data when available and use cached data during rebuilds
        if (snap.hasData) {
          _cachedData = snap.data;
        }

        final dataToUse = _cachedData ?? snap.data;
        final totals = (dataToUse?['totals'] as Map?) ?? const {};
        final receipts = int.tryParse((totals['totalReceipts'] ?? '0').toString()) ?? 0;
        final totalSpent = double.tryParse((totals['totalSpent'] ?? '0').toString()) ?? 0;
        final uniqueProducts = int.tryParse((totals['uniqueProducts'] ?? '0').toString()) ?? 0;
        return Row(children: [
          _StatTile(value: receipts.toString(), label: t.profileReceiptsScanned), _DividerV(),
          _StatTile(value: uniqueProducts.toString(), label: t.profileUniqueProducts), _DividerV(),
          _StatTile(value: currency.format(totalSpent), label: t.profileTotalSpent),
        ]);
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value; final String label;
  const _StatTile({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: FlowColors.text(context))),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]));
  }
}

class _DividerV extends StatelessWidget {
  const _DividerV();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 12), color: FlowColors.divider(context));
}

class _OrnamentsPainter extends CustomPainter {
  final Color color; _OrnamentsPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final topBand = (size.height * 0.35).clamp(60.0, 140.0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(24, topBand - 40, 16, 16), const Radius.circular(4)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width - 40, topBand - 50, 14, 14), const Radius.circular(4)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .3, topBand - 64, 10, 10), const Radius.circular(3)), paint);
    canvas.drawCircle(Offset(size.width * .75, topBand - 20), 6, paint);
    canvas.drawCircle(Offset(size.width * .15, topBand + 10), 8, paint);
  }
  @override
  bool shouldRepaint(covariant _OrnamentsPainter oldDelegate) => false;
}
