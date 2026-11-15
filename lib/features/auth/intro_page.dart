import '../../core/theme.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/ui.dart';
import 'auth_widgets.dart';

/// A swipeable introduction, separate from the shared web registration contract.
class IntroPage extends ConsumerStatefulWidget {
  const IntroPage({super.key, this.onDemo});
  final VoidCallback? onDemo;
  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends ConsumerState<IntroPage> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _move(int page) {
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page, duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final titles = [
      t('Fair bezahlen.\nKlar abrechnen.', 'Pošteno plačilo.\nJasni računi.'),
      t('Aus Zahlen\nwird Klarheit.', 'Od številk\ndo jasnosti.'),
      t('Ihr Unternehmen.\nÜberall dabei.', 'Vaše podjetje.\nVedno z vami.'),
    ];
    final copy = [
      t(
        'Rechnungen, Belege und Kontakte. Ein aufgeräumter Ort für Ihre Finanzen.',
        'Računi, dokumenti in stiki. Pregleden prostor za vaše finance.',
      ),
      t(
        'Entgelttransparenz verstehen. Analysen und Berichte für Ihren nächsten Schritt.',
        'Razumite transparentnost plač. Analize in poročila za vaš naslednji korak.',
      ),
      t(
        'Ein Equitensa-Konto für App und Web. Dieselbe Firma, dieselben Daten.',
        'En račun Equitensa za aplikacijo in splet. Isto podjetje, isti podatki.',
      ),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '${t('Schritt', 'Korak')} ${_index + 1} / 3',
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 3,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: i <= _index ? context.eq.accent : context.eq.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 36),
              TextButton(
                onPressed: _index < 2 ? () => _move(2) : () => context.go('/register'),
                style: TextButton.styleFrom(foregroundColor: context.eq.muted),
                child: Text(t('Überspringen', 'Preskoči'), style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => PageView.builder(
              controller: _pages,
              itemCount: 3,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, i) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: (box.maxHeight * .32).clamp(120.0, 200.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: box.maxWidth - 56,
                          height: 226,
                          child: _IntroVisual(index: i, t: t),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Kicker(['FINANCE', 'PAY', 'EQUITENSA CONNECT'][i], color: context.eq.accent),
                    const SizedBox(height: 14),
                    Text(
                      titles[i],
                      style: TextStyle(
                        color: context.eq.ink,
                        fontSize: 36,
                        letterSpacing: -1.6,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(copy[i], style: TextStyle(color: context.eq.muted, fontSize: 14, height: 1.7)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EqButton(
                label: _index == 2 ? t('Konto erstellen', 'Ustvari račun') : t('Weiter', 'Naprej'),
                trailingIcon: LucideIcons.arrowRight,
                onPressed: () => _index == 2 ? context.go('/register') : _move(_index + 1),
              ),
              const SizedBox(height: 12),
              GlassButton(label: t('Anmelden', 'Prijava'), onPressed: () => context.go('/login')),
              if (widget.onDemo != null)
                TextButton(
                  onPressed: widget.onDemo,
                  child: Text(
                    t('Lokale Demo öffnen', 'Odpri lokalni demo'),
                    style: TextStyle(color: context.eq.muted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntroVisual extends StatelessWidget {
  const _IntroVisual({required this.index, required this.t});
  final int index;
  final Tr t;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const RadialGradient(colors: [Color(0xFF343044), Color(0x00343044)], radius: .85),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: switch (index) {
        0 => _finance(context),
        1 => _pay(context),
        _ => _connected(context),
      },
    ),
  );

  Widget _finance(BuildContext context) => Transform.rotate(
    angle: -.035,
    child: GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.receiptText, color: context.eq.accent, size: 22),
              const SizedBox(width: 12),
              Text(
                t('Rechnung', 'Račun'),
                style: TextStyle(color: context.eq.ink, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _tag(context, t('Vorschau', 'Predogled')),
            ],
          ),
          const SizedBox(height: 24),
          _line(context, .7),
          const SizedBox(height: 8),
          _line(context, .45),
          const SizedBox(height: 24),
          Divider(color: context.eq.line),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                t('Alles an einem Ort', 'Vse na enem mestu'),
                style: TextStyle(color: context.eq.muted, fontSize: 11),
              ),
              const Spacer(),
              const Icon(LucideIcons.check, color: Color(0xFF8ED9B9), size: 18),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _pay(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Kicker('PAY INSIGHTS', color: context.eq.accent),
            const Spacer(),
            _tag(context, t('Vorschau', 'Predogled')),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 6; i++)
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: [.42, .62, .5, .85, .7, 1.0][i],
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: i == 5
                            ? context.eq.accent
                            : Color.lerp(const Color(0xFF393244), const Color(0xFF8E77BD), i / 6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          t('Verstehen. Vergleichen. Vorbereiten.', 'Razumite. Primerjajte. Pripravite.'),
          style: TextStyle(color: context.eq.muted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _connected(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _device(context, LucideIcons.smartphone),
            const SizedBox(width: 16),
            Icon(LucideIcons.arrowLeftRight, color: context.eq.accent, size: 18),
            const SizedBox(width: 16),
            _device(context, LucideIcons.monitor),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          t('Ein Konto. Alles verbunden.', 'En račun. Vse povezano.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.eq.ink, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Text('iOS  /  Android  /  Web', style: TextStyle(color: context.eq.muted, fontSize: 11, letterSpacing: 1)),
      ],
    ),
  );

  Widget _device(BuildContext context, IconData icon) => Container(
    width: 60,
    height: 66,
    decoration: BoxDecoration(
      color: context.eq.violetSoft,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: context.eq.line),
    ),
    child: Icon(icon, color: context.eq.accent, size: 28),
  );

  Widget _tag(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: context.eq.violetSoft, borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: context.eq.accent, fontSize: 9)),
  );

  Widget _line(BuildContext context, double width) => FractionallySizedBox(
    widthFactor: width,
    child: Container(
      height: 7,
      decoration: BoxDecoration(color: context.eq.line, borderRadius: BorderRadius.circular(3)),
    ),
  );
}
