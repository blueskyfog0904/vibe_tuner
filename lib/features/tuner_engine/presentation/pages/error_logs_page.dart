import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/logging/error_reporter.dart';

class ErrorLogsPage extends StatefulWidget {
  const ErrorLogsPage({super.key});

  @override
  State<ErrorLogsPage> createState() => _ErrorLogsPageState();
}

class _ErrorLogsPageState extends State<ErrorLogsPage> {
  late final Stream<List<ReportedError>> _stream;
  late List<ReportedError> _cached;

  @override
  void initState() {
    super.initState();
    _stream = AppErrorReporter.recentErrorsStream();
    _cached = AppErrorReporter.getRecentErrors();
  }

  Future<void> _copyLogs() async {
    final text = AppErrorReporter.exportRecentErrorsText();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복사할 로그가 없습니다.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그를 클립보드에 복사했습니다.')),
    );
  }

  void _clearLogs() {
    AppErrorReporter.clearRecentErrors();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그를 초기화했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: StreamBuilder<List<ReportedError>>(
        stream: _stream,
        initialData: _cached,
        builder: (context, snapshot) {
          final errors = snapshot.data ?? _cached;
          _cached = errors;
          if (errors.isEmpty) {
            return const Center(child: Text('수집된 에러가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: errors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reported = errors[index];
              final isFatal = reported.severity == ErrorSeverity.fatal;
              final color = isFatal ? Colors.red : Colors.orange;
              final contextText = _formatContextText(reported.context);
              return Card(
                child: ListTile(
                  title: Text(
                    reported.error.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    contextText == null
                        ? '${reported.source} • ${reported.timestamp.toLocal()}'
                        : '${reported.source} • ${reported.timestamp.toLocal()}\n$contextText',
                    maxLines: contextText == null ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: contextText != null,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: color.withValues(alpha: 0.15),
                    ),
                    child: Text(
                      isFatal ? 'FATAL' : 'WARN',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String? _formatContextText(Map<String, Object?> context) {
    if (context.isEmpty) return null;
    return context.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
  }
}
