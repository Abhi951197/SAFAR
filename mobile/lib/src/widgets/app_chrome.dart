import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.showImageBackground = false,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool showImageBackground;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF7F8FF), Color(0xFFFFFFFF)],
              ),
            ),
          ),
          if (showImageBackground) ...[
            Image.asset('assets/images/safar_background.png', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.70),
                    Colors.white.withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ],
          SafeArea(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

class SafarLogo extends StatelessWidget {
  const SafarLogo({this.height = 86, this.compact = false, super.key});

  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/safar_logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class SafarHeroImage extends StatelessWidget {
  const SafarHeroImage({this.height = 260, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: Image.asset('assets/images/safar_background.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Text(
              'Reflect. Write. Grow.',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({required this.child, this.padding = const EdgeInsets.all(16), super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A111827), blurRadius: 28, offset: Offset(0, 16)),
        ],
      ),
      child: child,
    );
  }
}

class GoogleButton extends StatelessWidget {
  const GoogleButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppTheme.border),
        minimumSize: const Size.fromHeight(50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Text(
              'G',
              style: TextStyle(
                color: Color(0xFF4285F4),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class MediaPill extends StatelessWidget {
  const MediaPill({required this.icon, required this.label, required this.onTap, this.selected = false, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? AppTheme.primary : AppTheme.textPrimary,
          backgroundColor: selected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
          minimumSize: const Size(0, 44),
        ),
      ),
    );
  }
}

class MountainMemoryArt extends StatelessWidget {
  const MountainMemoryArt({this.height = 260, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _MountainPainter(),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({required this.child, this.padding = const EdgeInsets.all(16), this.onTap, super.key});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0F111827), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: content);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF3DE), Color(0xFFEAF4FF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final sun = Paint()..color = const Color(0xFFFFD98A);
    canvas.drawCircle(Offset(size.width * 0.53, size.height * 0.22), 16, sun);

    void mountain(List<Offset> points, Color color) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    mountain([
      Offset(0, size.height * 0.55),
      Offset(size.width * 0.18, size.height * 0.36),
      Offset(size.width * 0.42, size.height * 0.64),
      Offset(size.width * 0.67, size.height * 0.30),
      Offset(size.width, size.height * 0.52),
    ], const Color(0xFF9BA9C9));
    mountain([
      Offset(0, size.height * 0.70),
      Offset(size.width * 0.22, size.height * 0.48),
      Offset(size.width * 0.48, size.height * 0.68),
      Offset(size.width * 0.78, size.height * 0.38),
      Offset(size.width, size.height * 0.60),
    ], const Color(0xFF6E8BA9));

    final lake = Path()
      ..moveTo(0, size.height * 0.68)
      ..cubicTo(size.width * 0.30, size.height * 0.58, size.width * 0.64, size.height * 0.58, size.width, size.height * 0.66)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(lake, Paint()..color = const Color(0xFFB9D7E7));

    final reflection = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.74 + i * 0.03);
      canvas.drawLine(Offset(size.width * (0.24 + i * 0.035), y), Offset(size.width * (0.78 - i * 0.035), y), reflection);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
