import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

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
      _pages.animateToPage(page, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final titles = [
      t('Ihr Business.\nIn Ihrer Hand.', 'Vaše podjetje.\nV vaših rokah.'),
      t('Faire Gehälter.\nKlare Entscheidungen.', 'Pravične plače.\nJasne odločitve.'),
      t('Ein Konto.\nAlles verbunden.', 'En račun.\nVse povezano.'),
    ];
    final descriptions = [
      t(
        'Rechnungen, Ausgaben und Kontakte. Ihr Arbeitsalltag bekommt einen klaren Überblick.',
        'Računi, stroški in stiki. Jasen pregled vašega delovnega dne.',
      ),
      t(
        'Entgeltdaten verstehen und Berichte vorbereiten. Schritt für Schritt zu mehr Transparenz.',
        'Razumite podatke o plačah in pripravite poročila. Korak za korakom do več preglednosti.',
      ),
      t(
        'Am Schreibtisch beginnen. Unterwegs weitermachen. App und Web greifen auf dasselbe Unternehmen zu.',
        'Začnite za mizo. Nadaljujte na poti. Aplikacija in splet uporabljata isto podjetje.',
      ),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              if (_index > 0)
                IconButton(
                  tooltip: t('Zurück', 'Nazaj'),
                  onPressed: () => _move(_index - 1),
                  icon: const Icon(LucideIcons.arrowLeft, size: 19),
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              TextButton(
                onPressed: () => _index < 2 ? _move(2) : context.go('/register'),
                child: Text(t('Überspringen', 'Preskoči'), style: TextStyle(color: context.eq.muted, fontSize: 12)),
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
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                child: Column(
                  children: [
                    SizedBox(
                      height: (box.maxHeight * .51).clamp(150.0, 310.0),
                      width: double.infinity,
                      child: FittedBox(
                        child: SizedBox(
                          width: 320,
                          height: 260,
                          child: _IntroScene(index: i, t: t),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: context.eq.violetSoft, borderRadius: BorderRadius.circular(30)),
                      child: Text(
                        ['EQUITENSA FINANCE', 'EQUITENSA PAY', 'EQUITENSA CONNECT'][i],
                        style: TextStyle(
                          color: context.eq.accent,
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      titles[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.eq.ink,
                        fontSize: 34,
                        letterSpacing: -1.4,
                        height: 1.13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 365),
                      child: Text(
                        descriptions[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.eq.muted, fontSize: 14, height: 1.65),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: '${t('Schritt', 'Korak')} ${_index + 1} / 3',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Semantics(
                        label: '${t('Schritt', 'Korak')} ${i + 1}',
                        selected: _index == i,
                        button: true,
                        child: GestureDetector(
                          onTap: () => _move(i),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 40,
                            height: 36,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: _index == i ? 28 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _index == i ? context.eq.accent : context.eq.line,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              EqButton(
                label: _index == 2 ? t('Konto erstellen', 'Ustvari račun') : t('Weiter', 'Naprej'),
                trailingIcon: LucideIcons.arrowRight,
                onPressed: () => _index == 2 ? context.go('/register') : _move(_index + 1),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  t('Anmelden', 'Prijava'),
                  style: TextStyle(color: context.eq.ink, fontWeight: FontWeight.w600),
                ),
              ),
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

class _IntroScene extends StatelessWidget {
  const _IntroScene({required this.index, required this.t});
  final int index;
  final Tr t;
  Widget _panel(BuildContext context, Widget child, {double width = 246}) => Container(
    width: width,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: context.eq.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: context.eq.line),
      boxShadow: [
        BoxShadow(color: context.eq.accent.withValues(alpha: .09), blurRadius: 30, offset: const Offset(0, 16)),
      ],
    ),
    child: child,
  );
  Widget _bar(BuildContext context, double width) => Container(
    width: width,
    height: 6,
    margin: const EdgeInsets.only(top: 9),
    decoration: BoxDecoration(color: context.eq.line, borderRadius: BorderRadius.circular(8)),
  );
  Widget _badge(BuildContext context, IconData icon, String title) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: context.eq.surface,
      border: Border.all(color: context.eq.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: context.eq.accent),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(color: context.eq.ink, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [context.eq.accent.withValues(alpha: .14), context.eq.accent.withValues(alpha: .025)],
          ),
        ),
      ),
      Container(
        width: 215,
        height: 215,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.eq.accent.withValues(alpha: .12)),
        ),
      ),
      if (index == 0) ...[
        Transform.rotate(
          angle: -.06,
          child: _panel(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.fileText, size: 22, color: context.eq.accent),
                    const Spacer(),
                    Text('EQUITENSA', style: TextStyle(color: context.eq.muted, fontSize: 9, letterSpacing: 1.3)),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  t('Ihre nächste Rechnung', 'Vaš naslednji račun'),
                  style: TextStyle(color: context.eq.ink, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                _bar(context, 140),
                _bar(context, 90),
                const SizedBox(height: 17),
                Divider(color: context.eq.line),
                _bar(context, 185),
                _bar(context, 120),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Positioned(right: 0, bottom: 20, child: _badge(context, LucideIcons.check, t('Alles im Blick', 'Vse na očeh'))),
      ] else if (index == 1) ...[
        _panel(
          context,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('PAY INSIGHTS', style: TextStyle(color: context.eq.muted, fontSize: 10, letterSpacing: 1.2)),
                  const Spacer(),
                  Icon(LucideIcons.chartNoAxesCombined, size: 18, color: context.eq.accent),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 6; i++)
                      Expanded(
                        child: Container(
                          height: [38.0, 65.0, 50.0, 82.0, 68.0, 98.0][i],
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: context.eq.accent.withValues(alpha: i == 5 ? 1 : .15 + i * .09),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _bar(context, 130),
            ],
          ),
        ),
        Positioned(
          left: 0,
          bottom: 15,
          child: _badge(context, LucideIcons.shieldCheck, t('Klarheit schaffen', 'Ustvarite jasnost')),
        ),
      ] else ...[
        Positioned(
          left: 20,
          top: 40,
          child: _panel(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.monitor, size: 74, color: context.eq.accent),
                const SizedBox(height: 13),
                _bar(context, 105),
                _bar(context, 75),
              ],
            ),
            width: 190,
          ),
        ),
        Positioned(
          right: 18,
          top: 65,
          child: _panel(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.smartphone, size: 62, color: context.eq.accent),
                const SizedBox(height: 12),
                Icon(LucideIcons.check, size: 22, color: context.eq.accent),
              ],
            ),
            width: 92,
          ),
        ),
        Positioned(
          bottom: 10,
          child: _badge(context, LucideIcons.refreshCw, t('App & Web verbunden', 'Aplikacija in splet povezana')),
        ),
      ],
    ],
  );
}
