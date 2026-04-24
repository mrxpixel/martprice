import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'freeform/freeform_screen.dart';
import 'model/gemma_service.dart';
import 'testharness/harness_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();
  runApp(const MartPriceApp());
}

class MartPriceApp extends StatelessWidget {
  const MartPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mart Price Harness',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

enum _LoadState { idle, loading, ready, missing, error }

class _HomeState extends State<_Home> {
  int _tab = 0;
  _LoadState _state = _LoadState.idle;
  String? _errorMessage;
  String? _modelPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      await GemmaService.instance.load();
      if (!mounted) return;
      setState(() {
        _state = _LoadState.ready;
        _modelPath = GemmaService.instance.modelPath;
      });
    } on ModelMissingException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.missing;
        _modelPath = e.expectedPath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (_state) {
      case _LoadState.ready:
        body = IndexedStack(
          index: _tab,
          children: const [HarnessScreen(), FreeformScreen()],
        );
        break;
      case _LoadState.loading:
        body = const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading Gemma 4 E2B...'),
            ],
          ),
        );
        break;
      case _LoadState.missing:
        body = _MissingModelView(
          expectedPath: _modelPath ?? '(unknown)',
          onRetry: _load,
        );
        break;
      case _LoadState.error:
        body = _ErrorView(
            message: _errorMessage ?? 'Unknown error', onRetry: _load);
        break;
      case _LoadState.idle:
        body = const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Test Harness' : 'Free-form'),
      ),
      body: body,
      bottomNavigationBar: _state == _LoadState.ready
          ? NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.checklist), label: 'Harness'),
                NavigationDestination(
                    icon: Icon(Icons.edit_note), label: 'Free-form'),
              ],
            )
          : null,
    );
  }
}

class _MissingModelView extends StatelessWidget {
  const _MissingModelView({required this.expectedPath, required this.onRetry});
  final String expectedPath;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Model file not found',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Expected at:'),
          SelectableText(expectedPath,
              style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 16),
          const Text(
              'Sideload the gemma-4-E2B-it-int4.litertlm file into the app\'s documents directory, then tap Retry. See README for the adb/Xcode steps.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Failed to load model',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(message),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
