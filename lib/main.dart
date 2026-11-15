import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(
    // Retries are disabled so offline/denied states surface immediately and
    // mutations are never replayed behind the user's back.
    ProviderScope(retry: (_, _) => null, child: const EquitensaApp()),
  );
}
