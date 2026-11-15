import 'dart:convert';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/files.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../finance/finance_common.dart';

typedef Data = Map<String, dynamic>;
Future<({String name, Uint8List bytes})?> pickDocument({int maxBytes = 4 * 1024 * 1024}) async {
  final file = await FilePicker.pickFile();
  if (file == null) return null;
  final length = await file.length();
  if (length != null && length > maxBytes) throw StateError('PAYLOAD_TOO_LARGE');
  final bytes = await file.readAsBytes();
  if (bytes.length > maxBytes) throw StateError('PAYLOAD_TOO_LARGE');
  return (name: file.name, bytes: bytes);
}

Data object(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : {};
List<Data> records(dynamic value) => value is List ? value.whereType<Map>().map(object).toList() : [];
Data copyData(Data value) => object(jsonDecode(jsonEncode(value)));
dynamic readPath(Data value, String path) {
  dynamic current = value;
  for (final part in path.split('.')) {
    current = current is Map
        ? current[part]
        : current is List
        ? current[int.parse(part)]
        : null;
  }
  return current;
}

void writePath(Data value, String path, dynamic data) {
  final parts = path.split('.');
  dynamic current = value;
  for (var i = 0; i < parts.length - 1; i++) {
    final part = parts[i];
    if (current is List) {
      current = current[int.parse(part)];
    } else {
      current[part] ??= <String, dynamic>{};
      current = current[part];
    }
  }
  if (current is List) {
    current[int.parse(parts.last)] = data;
  } else {
    current[parts.last] = data;
  }
}

class Input {
  const Input(this.key, this.de, this.sl, {this.kind = 'text', this.options = const {}, this.required = false});
  final String key, de, sl, kind;
  final Map<String, String> options;
  final bool required;
}

class DataFields extends StatefulWidget {
  const DataFields({super.key, required this.value, required this.fields, required this.onChanged});
  final Data value;
  final List<Input> fields;
  final VoidCallback onChanged;
  @override
  State<DataFields> createState() => _DataFieldsState();
}

class _DataFieldsState extends State<DataFields> {
  final _controllers = <String, TextEditingController>{};
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ProviderScope.containerOf(context).read(languageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in widget.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Builder(
              builder: (context) {
                final label = lang == 'sl' ? field.sl : field.de;
                final value = readPath(widget.value, field.key);
                if (field.kind == 'bool') {
                  if (value == null) writePath(widget.value, field.key, false);
                  return SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label, style: TextStyle(color: context.eq.ink, fontSize: 14)),
                    value: value == true,
                    onChanged: (v) {
                      setState(() => writePath(widget.value, field.key, v));
                      widget.onChanged();
                    },
                  );
                }
                if (field.kind == 'list') {
                  final selected = value is List ? List<String>.from(value) : <String>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final option in field.options.entries)
                            FilterChip(
                              label: Text(option.value),
                              selected: selected.contains(option.key),
                              onSelected: (on) {
                                setState(() {
                                  if (on) {
                                    selected.add(option.key);
                                  } else {
                                    selected.remove(option.key);
                                  }
                                  writePath(widget.value, field.key, selected);
                                });
                                widget.onChanged();
                              },
                            ),
                        ],
                      ),
                      for (var i = 0; i < selected.length; i++)
                        Row(
                          children: [
                            Expanded(child: Text(field.options[selected[i]] ?? selected[i])),
                            IconButton(
                              tooltip: 'Nach oben / Navzgor',
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              onPressed: i == 0
                                  ? null
                                  : () {
                                      setState(() {
                                        final item = selected.removeAt(i);
                                        selected.insert(i - 1, item);
                                        writePath(widget.value, field.key, selected);
                                      });
                                      widget.onChanged();
                                    },
                            ),
                          ],
                        ),
                    ],
                  );
                }
                if (field.options.isNotEmpty) {
                  return DropdownButtonFormField<String>(
                    initialValue: field.options.containsKey(value?.toString()) ? value.toString() : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: label),
                    items: [
                      for (final e in field.options.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      writePath(widget.value, field.key, v);
                      widget.onChanged();
                    },
                  );
                }
                final controller = _controllers.putIfAbsent(
                  field.key,
                  () => TextEditingController(text: value?.toString() ?? ''),
                );
                final input = EqField(
                  label: field.required ? '$label *' : label,
                  controller: controller,
                  maxLines: field.kind == 'long' || field.kind == 'fileText' ? 3 : 1,
                  obscure: field.kind == 'password',
                  keyboardType: field.kind == 'number'
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : field.kind == 'date'
                      ? TextInputType.datetime
                      : TextInputType.text,
                  validator: field.required
                      ? (v) => v == null || v.trim().isEmpty ? (lang == 'sl' ? 'Obvezno polje' : 'Pflichtfeld') : null
                      : null,
                  onChanged: (v) {
                    writePath(
                      widget.value,
                      field.key,
                      field.kind == 'number' ? num.tryParse(v.replaceAll(',', '.')) ?? v : v,
                    );
                    widget.onChanged();
                  },
                );
                if (field.kind == 'fileText') {
                  return Column(
                    children: [
                      input,
                      TextButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: Text(lang == 'sl' ? 'Naloži besedilno datoteko' : 'Textdatei laden'),
                        onPressed: () async {
                          final file = await pickDocument();
                          if (file == null || !mounted) return;
                          controller.text = utf8.decode(file.bytes);
                          writePath(widget.value, field.key, controller.text);
                          widget.onChanged();
                        },
                      ),
                    ],
                  );
                }
                return input;
              },
            ),
          ),
      ],
    );
  }
}

Future<Data?> editData(
  BuildContext context, {
  required String title,
  required List<Input> fields,
  Data initial = const {},
  required Future<void> Function(Data) save,
  String? action,
}) => showModalBottomSheet<Data>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  useSafeArea: true,
  backgroundColor: context.eq.surface,
  builder: (_) => _Editor(title: title, fields: fields, initial: initial, save: save, action: action),
);

class _Editor extends StatefulWidget {
  const _Editor({required this.title, required this.fields, required this.initial, required this.save, this.action});
  final String title;
  final List<Input> fields;
  final Data initial;
  final Future<void> Function(Data) save;
  final String? action;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final Data _value = copyData(widget.initial);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  Object? _error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DraggableScrollableSheet(
      initialChildSize: .85,
      minChildSize: .4,
      maxChildSize: .96,
      expand: false,
      builder: (context, scroll) => Form(
        key: _form,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.title,
              style: TextStyle(color: context.eq.ink, fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            AbsorbPointer(
              absorbing: _busy,
              child: DataFields(value: _value, fields: widget.fields, onChanged: () {}),
            ),
            if (_error != null) NoticeBanner(_error is Exception ? _error.toString() : 'Speichern fehlgeschlagen'),
            const SizedBox(height: 16),
            EqButton(
              label: widget.action ?? 'Speichern / Shrani',
              busy: _busy,
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  _busy = true;
                  _error = null;
                });
                try {
                  await widget.save(_value);
                  if (context.mounted) Navigator.pop(context, _value);
                } catch (error) {
                  if (mounted) setState(() => _error = error);
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmAction(BuildContext context, String title, String description) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen / Prekliči')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Bestätigen / Potrdi')),
        ],
      ),
    ) ??
    false;
Future<void> downloadFile(BuildContext context, WidgetRef ref, String path, String filename, {Data? body}) async {
  try {
    final api = ref.read(apiClientProvider);
    final bytes = body == null ? await api.getBytes(path) : await api.postBytes(path, body);
    await shareBytes(
      bytes,
      filename,
      filename.endsWith('.pdf')
          ? 'application/pdf'
          : filename.endsWith('.zip')
          ? 'application/zip'
          : 'application/octet-stream',
    );
  } catch (e) {
    if (context.mounted) showApiError(context, e);
  }
}

class RemotePage extends ConsumerStatefulWidget {
  const RemotePage({super.key, required this.title, required this.load, required this.builder});
  final String title;
  final Future<Data> Function(WidgetRef) load;
  final Widget Function(BuildContext, WidgetRef, Data, VoidCallback) builder;
  @override
  ConsumerState<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends ConsumerState<RemotePage> with WidgetsBindingObserver {
  late Future<Data> _future;
  int? _year;
  void _reload() {
    if (mounted) setState(() => _future = widget.load(ref));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = widget.load(ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(payYearProvider);
    if (_year != null && _year != year) {
      _future = widget.load(ref);
    }
    _year = year;
    return SubPage(
      title: widget.title,
      kicker: 'Equitensa',
      actions: [
        IconButton(tooltip: 'Aktualisieren / Osveži', onPressed: _reload, icon: const Icon(LucideIcons.refreshCw)),
      ],
      child: FutureBuilder<Data>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(snap.error.toString(), textAlign: TextAlign.center),
                  ),
                  EqButton(label: 'Erneut versuchen / Poskusi znova', expand: false, onPressed: _reload),
                ],
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 48),
              children: [widget.builder(context, ref, snap.data!, _reload)],
            ),
          );
        },
      ),
    );
  }
}

Widget entryCard(BuildContext context, String title, String subtitle, {Widget? trailing, VoidCallback? onTap}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EqCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: context.eq.ink, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: context.eq.muted, height: 1.5, fontSize: 12)),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );

class YearSelector extends ConsumerWidget {
  const YearSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownButtonFormField<int>(
    initialValue: ref.watch(payYearProvider),
    decoration: const InputDecoration(labelText: 'Berichtsjahr / Leto poročanja'),
    items: [for (var y = 2000; y <= DateTime.now().year + 6; y++) DropdownMenuItem(value: y, child: Text('$y'))],
    onChanged: (y) {
      if (y != null) ref.read(payYearProvider.notifier).set(y);
    },
  );
}

class AsyncAction extends StatefulWidget {
  const AsyncAction({super.key, required this.label, required this.action});
  final String label;
  final Future<void> Function() action;
  @override
  State<AsyncAction> createState() => _AsyncActionState();
}

class _AsyncActionState extends State<AsyncAction> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => EqButton(
    label: widget.label,
    kind: BtnKind.secondary,
    busy: _busy,
    onPressed: () async {
      if (_busy) return;
      setState(() => _busy = true);
      try {
        await widget.action();
      } catch (e) {
        if (context.mounted) showApiError(context, e);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    },
  );
}
