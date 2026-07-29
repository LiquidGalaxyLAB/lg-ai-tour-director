import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/location.dart';
import '../../providers/ssh_provider.dart';
import '../../services/maps/map_sync_service.dart';

class SyncMapView extends ConsumerStatefulWidget {
  const SyncMapView({
    super.key,
    required this.locations,
    this.height,
    this.frameAllLocations = true,
    this.focusLocation,
    this.showSyncChip = true,
    this.onExpand,
  });

  final List<TourLocation> locations;

  final double? height;

  final bool frameAllLocations;

  final TourLocation? focusLocation;

  final bool showSyncChip;

  /// When set, a fullscreen button is shown (bottom-left). Tapping it should
  /// open a full-screen explore map (see FullscreenMapScreen).
  final VoidCallback? onExpand;

  @override
  ConsumerState<SyncMapView> createState() => _SyncMapViewState();
}

class _SyncMapViewState extends ConsumerState<SyncMapView> {
  final Completer<GoogleMapController> _controller = Completer();

  List<TourLocation> get _geocoded => widget.locations
      .where((l) => l.latitude != null && l.longitude != null)
      .toList();

  CameraPosition get _initialCamera {
    final focus = widget.focusLocation;
    if (focus?.latitude != null) {
      return CameraPosition(
        target: LatLng(focus!.latitude!, focus.longitude!),
        zoom: 15,
      );
    }
    final pts = _geocoded;
    if (pts.isEmpty) return const CameraPosition(target: LatLng(0, 0), zoom: 2);
    final first = pts.first;
    return CameraPosition(
      target: LatLng(first.latitude!, first.longitude!),
      zoom: pts.length == 1 ? 14 : 5,
    );
  }

  Set<Marker> get _markers {
    final pts = _geocoded;
    return {
      for (var i = 0; i < pts.length; i++)
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(pts[i].latitude!, pts[i].longitude!),
          infoWindow: InfoWindow(title: '${i + 1}. ${pts[i].name}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          // Tapping a marker flies the phone camera there — which then syncs to
          // the rig on idle (Screen C "interactive recap" behaviour).
          onTap: () => _animateTo(pts[i]),
        ),
    };
  }

  Future<void> _animateTo(TourLocation loc) async {
    if (loc.latitude == null) return;
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(loc.latitude!, loc.longitude!), 15),
    );
  }

  Future<void> _frameAll() async {
    final pts = _geocoded;
    if (pts.length < 2) return;
    var minLat = pts.first.latitude!, maxLat = pts.first.latitude!;
    var minLng = pts.first.longitude!, maxLng = pts.first.longitude!;
    for (final p in pts) {
      minLat = p.latitude! < minLat ? p.latitude! : minLat;
      maxLat = p.latitude! > maxLat ? p.latitude! : maxLat;
      minLng = p.longitude! < minLng ? p.longitude! : minLng;
      maxLng = p.longitude! > maxLng ? p.longitude! : maxLng;
    }
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        48,
      ),
    );
  }

  @override
  void didUpdateWidget(SyncMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-follow the active scene when it changes.
    final focus = widget.focusLocation;
    if (focus != null && focus.name != oldWidget.focusLocation?.name) {
      _animateTo(focus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(
      sshConnectionProvider.select((s) => s.isConnected),
    );

    final Widget map = GoogleMap(
      initialCameraPosition: _initialCamera,
      mapType: MapType.satellite,
      markers: _markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      // Claim drag gestures so an embedding scroll view (e.g. the Preview /
      // Saved lists) can't swallow the pan before the map sees it — otherwise
      // the camera never moves and nothing syncs to the rig.
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      onMapCreated: (c) {
        if (!_controller.isCompleted) _controller.complete(c);
        if (widget.focusLocation == null && widget.frameAllLocations) {
          _frameAll();
        }
      },
      onCameraMove: (pos) => MapSyncService.instance.onCameraMove(pos),
      onCameraIdle: () => MapSyncService.instance.onCameraIdle(),
    );

    final content = Stack(
      children: [
        Positioned.fill(child: map),
        if (widget.showSyncChip)
          Positioned(
            right: 12,
            top: 12,
            child: _SyncChip(connected: connected),
          ),
        if (widget.onExpand != null)
          Positioned(
            left: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onExpand,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.fullscreen, size: 22, color: Colors.black87),
                ),
              ),
            ),
          ),
      ],
    );

    final rounded = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: content,
    );

    return widget.height == null
        ? rounded
        : SizedBox(height: widget.height, child: rounded);
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: connected ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Synced with Liquid Galaxy' : 'Not connected',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
