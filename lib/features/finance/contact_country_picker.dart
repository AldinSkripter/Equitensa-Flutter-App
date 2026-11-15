import 'package:material_ui/material_ui.dart';

import '../../domain/contact_countries.dart';
import '../../core/theme.dart';

String contactCountryName(String code, bool sl) {
  final value = contactCountries[code];
  return value == null
      ? code
      : sl
      ? value.sl
      : value.de;
}

Future<String?> chooseContactCountry(BuildContext context, {required String selected, required bool sl}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.eq.surface,
      builder: (_) => _CountryPicker(selected: selected, sl: sl),
    );

class _CountryPicker extends StatefulWidget {
  const _CountryPicker({required this.selected, required this.sl});
  final String selected;
  final bool sl;
  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final countries =
        contactCountries.keys
            .where((c) => '$c ${contactCountryName(c, widget.sl)}'.toLowerCase().contains(_query.toLowerCase()))
            .toList()
          ..sort((a, b) => contactCountryName(a, widget.sl).compareTo(contactCountryName(b, widget.sl)));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            Text(
              widget.sl ? 'Država kupca' : 'Land des Kunden',
              style: TextStyle(color: context.eq.ink, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.sl ? 'Poišči državo' : 'Land suchen',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: countries.length,
                itemBuilder: (c, i) {
                  final code = countries[i];
                  return ListTile(
                    title: Text(contactCountryName(code, widget.sl)),
                    leading: Text(
                      code,
                      style: TextStyle(color: context.eq.accent, fontWeight: FontWeight.w700),
                    ),
                    trailing: code == widget.selected ? Icon(Icons.check_circle, color: context.eq.accent) : null,
                    onTap: () => Navigator.pop(context, code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
