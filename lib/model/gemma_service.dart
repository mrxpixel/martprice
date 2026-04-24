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

  static const String _modelFileName = 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

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
      await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromFile(path)
          .install();
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.cpu,
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

    final chat = await model.createChat(
      temperature: 0.0,
      randomSeed: 1,
      topK: 1,
      systemInstruction: kSystemPrompt,
    );

    final stopwatch = Stopwatch()..start();
    try {
      await chat.addQueryChunk(Message.text(text: userMessage, isUser: true));
      final text = await chat.generateChatResponse();
      stopwatch.stop();
      return InferenceResult(
        text: text.toString().trim(),
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      await chat.close();
    }
  }

  Future<void> dispose() async {
    await _model?.close();
    _model = null;
  }
}
