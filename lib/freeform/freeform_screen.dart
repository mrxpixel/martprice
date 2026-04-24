import 'dart:convert';

import 'package:flutter/material.dart';

import '../model/gemma_service.dart';
import '../prompt/user_template.dart';

class FreeformScreen extends StatefulWidget {
  const FreeformScreen({super.key});

  @override
  State<FreeformScreen> createState() => _FreeformScreenState();
}

class _FreeformScreenState extends State<FreeformScreen> {
  final _jsonController = TextEditingController();
  final _queryController = TextEditingController();

  String? _jsonError;
  String? _output;
  int? _latencyMs;
  bool _running = false;

  @override
  void dispose() {
    _jsonController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _jsonError = null;
      _output = null;
      _latencyMs = null;
    });

    final raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      setState(() => _jsonError = 'JSON is empty.');
      return;
    }
    try {
      jsonDecode(raw);
    } on FormatException catch (e) {
      setState(() => _jsonError = 'Invalid JSON: ${e.message}');
      return;
    }

    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() => _running = true);
    try {
      final prompt = buildUserMessage(data: raw, query: query);
      final result = await GemmaService.instance.infer(prompt);
      if (!mounted) return;
      setState(() {
        _output = result.text;
        _latencyMs = result.latencyMs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _output = 'Error: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _output?.length ?? 0;
    final overflow = charCount > 200;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _jsonController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                labelText: 'DATA (JSON)',
                errorText: _jsonError,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _queryController,
            decoration: const InputDecoration(
              labelText: 'USER_QUERY (한국어)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_running ? '추론 중...' : 'Run'),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Output',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_latencyMs != null)
                        Text('${_latencyMs}ms · $charCount chars',
                            style: TextStyle(
                                color: overflow ? Colors.red : Colors.grey)),
                    ],
                  ),
                  if (overflow)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('⚠ Exceeds 200-char rule',
                          style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(_output ?? ''),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
