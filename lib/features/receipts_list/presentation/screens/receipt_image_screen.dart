import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/services/auth_service.dart';

class ReceiptImageScreen extends StatefulWidget {
  final String receiptId;
  const ReceiptImageScreen({super.key, required this.receiptId});

  @override
  State<ReceiptImageScreen> createState() => _ReceiptImageScreenState();
}

class _ReceiptImageScreenState extends State<ReceiptImageScreen> {
  late final ApiService _api;
  late final AuthService _auth;
  String? _imageUrl;
  Map<String, String>? _headers;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = sl<ApiService>();
    _auth = sl<AuthService>();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final info = await _api.getReceiptImageInfo(widget.receiptId);
      final direct = info['directImageUrl']?.toString();
      if (direct != null && direct.isNotEmpty) {
        _imageUrl = direct; // público (uploads)
        _headers = null;
      } else {
        // usar endpoint protegido
        final endpoints = info['endpoints'] as Map<String, dynamic>?;
        final original = endpoints?['original']?.toString();
        _imageUrl = original;
        final token = _auth.accessToken;
        _headers = token != null ? {'Authorization': 'Bearer $token'} : null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.receiptImageTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(t.errorPrefix(_error!)))
              : _imageUrl == null
                  ? Center(child: Text(t.noImageAvailable))
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          _imageUrl!,
                          headers: _headers,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        ),
                      ),
                    ),
    );
  }
}
