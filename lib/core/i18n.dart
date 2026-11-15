import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import 'providers.dart';

/// German / Slovenian inline translation like the web app's `L(de, sl)`.
class Tr {
  const Tr(this.lang);
  final String lang;
  bool get sl => lang == 'sl';
  String call(String de, String slText) => sl ? slText : de;
}

Tr trOf(WidgetRef ref) => Tr(ref.watch(languageProvider));

/// Locale used for number/date formatting; follows the company country, like the web.
class Fmt {
  const Fmt(this.country);
  final Country country;

  String money(int cents) => NumberFormat.simpleCurrency(
    locale: country.locale,
    name: 'EUR',
  ).format(cents / 100);

  String moneyShort(int cents) => NumberFormat.compactSimpleCurrency(
    locale: country.locale,
    name: 'EUR',
    decimalDigits: 0,
  ).format(cents / 100);

  String number(num v, {int digits = 2}) => NumberFormat.decimalPatternDigits(
    locale: country.locale,
    decimalDigits: digits,
  ).format(v);

  String percent(num v) => '${number(v)} %';

  static String today() => DateTime.now().toIso8601String().substring(0, 10);
}

Fmt fmtOf(WidgetRef ref) => Fmt(ref.watch(countryProvider));
