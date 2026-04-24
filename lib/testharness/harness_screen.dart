import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/gemma_service.dart';
import '../prompt/user_template.dart';
import 'pass_fail.dart';
import 'test_cases.dart';

class _Row {
  _Row(this.testCase);
  final TestCase testCase;
  bool running = false;
  String? output;
  int? latencyMs;
  PassFailResult? result;
  bool expanded = false;
}

class HarnessScreen extends StatefulWidget {
  const HarnessScreen({super.key});

  @override
  State<HarnessScreen> createState() => _HarnessScreenState();
}

class _HarnessScreenState extends State<HarnessScreen> {
  late final List<_Row> _rows =
      kTestCases.map((tc) => _Row(tc)).toList(growable: false);
  bool _runningAll = false;

  Future<String> _loadFixture(String asset) async {
    return rootBundle.loadString(asset);
  }

  Future<void> _runOne(_Row row) async {
    setState(() {
      row.running = true;
      row.output = null;
      row.latencyMs = null;
      row.result = null;
    });
    try {
      final data = await _loadFixture(row.testCase.fixtureAsset);
      final prompt =
          buildUserMessage(data: data, query: row.testCase.query);
      final res = await GemmaService.instance.infer(prompt);
      final check = evaluateAll(row.testCase.rules, res.text);
      if (!mounted) return;
      setState(() {
        row.output = res.text;
        row.latencyMs = res.latencyMs;
        row.result = check;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        row.output = 'Error: $e';
        row.result = const PassFailResult(
            pass: false, failures: ['exception during inference']);
      });
    } finally {
      if (mounted) setState(() => row.running = false);
    }
  }

  Future<void> _runAll() async {
    if (_runningAll) return;
    setState(() => _runningAll = true);
    try {
      for (final row in _rows) {
        await _runOne(row);
      }
    } finally {
      if (mounted) setState(() => _runningAll = false);
    }
  }

  String _buildMarkdown() {
    final b = StringBuffer()
      ..writeln('| TC | Pass | Latency | Chars | Output |')
      ..writeln('|----|------|---------|-------|--------|');
    for (final row in _rows) {
      final pass = row.result?.pass == true ? '✅' : '❌';
      final latency = row.latencyMs == null ? '—' : '${row.latencyMs}ms';
      final chars = row.output?.length ?? 0;
      final output =
          (row.output ?? '').replaceAll('\n', ' ').replaceAll('|', '\\|');
      b.writeln(
          '| ${row.testCase.id} | $pass | $latency | $chars | $output |');
    }
    return b.toString();
  }

  Future<void> _copyMarkdown() async {
    await Clipboard.setData(ClipboardData(text: _buildMarkdown()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results copied as markdown')));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _RowCard(
            row: _rows[i],
            onRun: _runningAll ? null : () => _runOne(_rows[i]),
            onToggle: () => setState(
                () => _rows[i].expanded = !_rows[i].expanded),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Row(
            children: [
              FloatingActionButton.extended(
                heroTag: 'copy',
                onPressed: _copyMarkdown,
                icon: const Icon(Icons.copy),
                label: const Text('Copy MD'),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.extended(
                heroTag: 'runall',
                onPressed: _runningAll ? null : _runAll,
                icon: _runningAll
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_circle),
                label: Text(_runningAll ? 'Running...' : 'Run all'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.row,
    required this.onRun,
    required this.onToggle,
  });

  final _Row row;
  final VoidCallback? onRun;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final pass = row.result?.pass;
    final status = row.running
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
        : pass == null
            ? const Icon(Icons.radio_button_unchecked, color: Colors.grey)
            : pass
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.cancel, color: Colors.red);

    final latencyText = row.latencyMs == null
        ? ''
        : ' · ${row.latencyMs}ms · ${row.output?.length ?? 0} chars';

    return Card(
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  status,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row.testCase.id} — ${row.testCase.title}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          'Q: ${row.testCase.query}$latencyText',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: onRun,
                  ),
                ],
              ),
              if (row.expanded) ...[
                const Divider(),
                if (row.output != null) ...[
                  const Text('Output:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  SelectableText(row.output!),
                  const SizedBox(height: 8),
                ],
                if (row.result != null && row.result!.failures.isNotEmpty) ...[
                  const Text('Failures:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.red)),
                  for (final f in row.result!.failures)
                    Text('• $f', style: const TextStyle(color: Colors.red)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
