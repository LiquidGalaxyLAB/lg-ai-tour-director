import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A small status dot, green when connected to the LG rig, red otherwise.
class ConnectionDot extends StatelessWidget {
  const ConnectionDot({super.key, required this.connected, this.size = 8});

  final bool connected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: connected ? AppColors.connected : AppColors.disconnected,
        shape: BoxShape.circle,
      ),
    );
  }
}
