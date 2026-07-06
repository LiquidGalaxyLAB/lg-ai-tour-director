import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/location.dart';
import '../../services/media/location_media_resolver.dart';

class LocationImage extends StatefulWidget {
  const LocationImage({
    super.key,
    required this.location,
    this.height,
    this.width,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  final TourLocation location;
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxFit fit;

  @override
  State<LocationImage> createState() => _LocationImageState();
}

class _LocationImageState extends State<LocationImage> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolveUrl();
  }

  @override
  void didUpdateWidget(LocationImage old) {
    super.didUpdateWidget(old);
    if (old.location.name != widget.location.name ||
        old.location.imageUrl != widget.location.imageUrl) {
      _future = _resolveUrl();
    }
  }

  Future<String> _resolveUrl() async {
    final direct = widget.location.imageUrl;
    if (direct != null && direct.isNotEmpty) return direct;
    final media = await LocationMediaResolver.instance.resolve(widget.location);
    return media.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: FutureBuilder<String>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _placeholder(loading: true);
          }
          final url = snap.data ?? '';
          if (url.isEmpty) return _placeholder();
          return Image.network(
            url,
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _placeholder(loading: true),
            errorBuilder: (context, _, _) => _placeholder(),
          );
        },
      ),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.googleBlueBright, AppColors.googleGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white70),
              ),
            )
          : const Icon(Icons.photo_outlined, color: Colors.white30, size: 28),
    );
  }
}
