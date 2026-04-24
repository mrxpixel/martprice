import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import '../prompt/system_prompt.dart';

class ModelMissingException implements Exception {
  ModelMissingException(this.expectedPath);
  final String expectedPath;
  @override
  String toString() =>
      'Model file not found at $expectedPath. See README for sideload instructions.';
}

class InferenceResult {
  const InferenceResult({
    required this.text,
    required this.latencyMs,
  });
  final String text;
  final int latencyMs;
}

/// Singleton wrapper around flutter_gemma for the validation harness.
/// Uses greedy decoding (temperature 0, topK 1) so pass/fail string
/// containment checks are deterministic.
class GemmaService {
  GemmaService._();
  static final GemmaService instance = GemmaService._();

  static const String _modelFileName = 'gemma-4-E2B-it.litertlm';

  InferenceModel? _model;
  bool _loading = false;
  String? _modelPath;

  bool get isReady => _model != null;
  String? get modelPath => _modelPath;

  /// Locates the sideloaded .litertlm under the app's documents dir.
  /// Throws [ModelMissingException] if absent.
  Future<String> resolveModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$_modelFileName';
    _modelPath = path;
    if (!await File(path).exists()) {
      throw ModelMissingException(path);
    }
    return path;
  }

  Future<void> load() async {
    if (_model != null || _loading) return;
    _loading = true;
    try {
      final path = await resolveModelPath();
      final plugin = FlutterGemmaPlugin.instance;
      await plugin.modelManager.setModelPath(path);
      _model = await plugin.createModel(
        modelType: ModelType.gemmaIt,
        preferredBackend: PreferredBackend.gpu,
        maxTokens: 4096,
      );
    } finally {
      _loading = false;
    }
  }

  /// Runs a single inference. Opens a fresh session each call so the system
  /// prompt is re-installed and TC5-style jailbreak attempts cannot persist.
  Future<InferenceResult> infer(String userMessage) async {
    final model = _model;
    if (model == null) {
      throw StateError('Model not loaded. Call load() first.');
    }

    final session = await model.createSession(
      temperature: 0.0,
      randomSeed: 1,
      topK: 1,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final composed = '$kSystemPrompt\n\n$userMessage';
      await session.addQueryChunk(Message(text: composed, isUser: true));
      final text = await session.getResponse();
      stopwatch.stop();
      return InferenceResult(
        text: text.trim(),
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      await session.close();
    }
  }

  Future<void> dispose() async {
    await _model?.close();
    _model = null;
  }
}
