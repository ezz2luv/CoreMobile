import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class CoreLogo extends StatelessWidget {
  const CoreLogo({super.key, this.size = 168});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F14),
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.18),
                blurRadius: 24,
              ),
            ],
          ),
          child: CustomPaint(painter: _ToothMarkPainter()),
        ),
        const SizedBox(height: 18),
        Text(
          'CORE',
          style: GoogleFonts.cormorantGaramond(
            fontSize: size * 0.22,
            letterSpacing: 8,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Онлайн-консультации со стоматологом',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ToothMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFF2BB8A8);
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.28)
      ..quadraticBezierTo(size.width * 0.18, size.height * 0.12, size.width * 0.5, size.height * 0.12)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.12, size.width * 0.78, size.height * 0.28)
      ..quadraticBezierTo(size.width * 0.92, size.height * 0.46, size.width * 0.78, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.88, size.width * 0.5, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.88, size.width * 0.22, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.08, size.height * 0.46, size.width * 0.22, size.height * 0.28)
      ..close();
    canvas.drawPath(path, fill);

    final face = Paint()..color = const Color(0xFF11161C);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.42), size.width * 0.16, face);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.header,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CustomPaint(painter: _ToothMarkPainter()),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Core',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Консультация со стоматологом',
                      style: TextStyle(color: AppColors.accentMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Тёмная 1', style: TextStyle(fontSize: 12)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.text, this.tone = BannerTone.success});

  final String text;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      BannerTone.success => AppColors.banner,
      BannerTone.error => const Color(0xFF4A1B1B),
    };
    final fg = switch (tone) {
      BannerTone.success => AppColors.bannerText,
      BannerTone.error => const Color(0xFFF5C2C2),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 14)),
    );
  }
}

enum BannerTone { success, error }

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: padding ?? const EdgeInsets.all(22),
      child: child,
    );
  }
}
