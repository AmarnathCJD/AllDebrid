import 'package:blurhash/blurhash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppBlurHashPlaceholder extends StatelessWidget {
  static const String defaultHash = 'LD8rtfI8RZDOyZVXRPakDziJgGsF';

  final BoxFit fit;
  final String blurHash;
  final Widget? fallbackIcon;
  final Color? backgroundColor;

  const AppBlurHashPlaceholder({
    super.key,
    this.fit = BoxFit.cover,
    this.blurHash = defaultHash,
    this.fallbackIcon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: backgroundColor ?? const Color(0xFF15151A),
          child: _DecodedBlurHash(
            blurHash: blurHash,
            fit: fit,
          ),
        ),
        if (fallbackIcon != null)
          Center(
            child: Opacity(
              opacity: 0.45,
              child: fallbackIcon,
            ),
          ),
      ],
    );
  }
}

class _DecodedBlurHash extends StatefulWidget {
  final String blurHash;
  final BoxFit fit;

  const _DecodedBlurHash({
    required this.blurHash,
    required this.fit,
  });

  @override
  State<_DecodedBlurHash> createState() => _DecodedBlurHashState();
}

class _DecodedBlurHashState extends State<_DecodedBlurHash> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _DecodedBlurHash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blurHash != widget.blurHash) {
      _decode();
    }
  }

  Future<void> _decode() async {
    try {
      final bytes = await BlurHash.decode(widget.blurHash, 32, 32);
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _bytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return const SizedBox.expand();
    }

    return Image.memory(
      _bytes!,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}
