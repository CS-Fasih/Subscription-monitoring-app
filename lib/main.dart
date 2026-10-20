import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_store.dart';
import 'ui/design.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = AppStore(await SharedPreferences.getInstance());
    await store.load();
    runApp(TallyApp(store: store));
  } catch (_) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storage_outlined,
                    size: 40,
                    color: Palette.green,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Tally couldn’t open device storage.',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enable browser storage or check device space, then try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TallyApp extends StatelessWidget {
  const TallyApp({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tally — Subscription monitor',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: AppShell(store: store),
  );
}
