import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/providers.dart';
import 'screens/pairing_screen.dart';
import 'screens/shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase.initializeApp() is intentionally deferred until first launch
  // to avoid the google-services.json requirement for non-FCM builds.
  runApp(const ProviderScope(child: BaumAgentApp()));
}

class BaumAgentApp extends ConsumerWidget {
  const BaumAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BaumAgent',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.dark),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const PairingScreen(),
      data: (authed) => authed ? const ShellScreen() : const PairingScreen(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const seed = Color(0xFF3b82f6);
  final cs = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: cs.surface,
    cardTheme: const CardThemeData(elevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      indicatorColor: cs.primaryContainer,
    ),
  );
}
