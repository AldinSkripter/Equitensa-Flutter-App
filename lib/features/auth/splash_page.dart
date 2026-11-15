import 'package:material_ui/material_ui.dart';

import '../../core/ui.dart';

/// Flutter launch surface, also matching the native launch screen colors.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111218),
    body: SafeArea(
      child: Stack(
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24212E),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF3D354E)),
                    ),
                    child: const LogoMark(size: 62),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Equitensa',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -1),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PAY  /  FINANCE',
                    style: TextStyle(color: Color(0xFFC6B6FF), fontSize: 10, letterSpacing: 3),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 42,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFFC6B6FF),
                  semanticsLabel: 'Equitensa wird geladen',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
