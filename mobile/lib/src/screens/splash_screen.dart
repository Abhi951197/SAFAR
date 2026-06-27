import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showImageBackground: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 680;
          return ListView(
            children: [
              SizedBox(height: compact ? 8 : 28),
              SafarLogo(height: compact ? 104 : 150),
              const SizedBox(height: 14),
              SafarHeroImage(height: compact ? 210 : 280),
              const SizedBox(height: 24),
              Text('Safar', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Every day is a new journey', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
              SizedBox(height: compact ? 20 : 44),
              ElevatedButton(onPressed: () {}, child: const Text('Get Started')),
              const SizedBox(height: 28),
              const Text('Reflect. Write. Grow.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          );
        },
      ),
    );
  }
}
