import 'package:flutter/cupertino.dart';

/// Port of LocalImage from ImageLoading.swift. Database rows store relative
/// paths like `images/raw/sprite/foo.png`; the files live under `assets/`.
class LocalImage extends StatelessWidget {
  const LocalImage(this.path, {super.key, this.size = 32, this.borderRadius});

  final String? path;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    if (path == null || path.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    Widget image = Image.asset(
      'assets/$path',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox(width: size, height: size),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}
