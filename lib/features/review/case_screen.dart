import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/network_utils.dart';
import '../../../core/sync/answer_queue.dart';
import '../data/quiz_repository.dart';
import '../domain/clinical_case.dart';
import 'case_view.dart';

final clinicalCaseProvider =
    FutureProvider.autoDispose.family<ClinicalCase, int>(
  (ref, id) => ref.read(quizRepositoryProvider).getCase(id),
);

/// One case opened from the catalog (route /case/:id).
class CaseScreen extends ConsumerWidget {
  const CaseScreen({super.key, required this.caseId});
  final int caseId;

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clinicalCaseProvider(caseId));
    return Scaffold(
      appBar: AppBar(title: const Text('Cas clinique')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(friendlyError(e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(clinicalCaseProvider(caseId)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (c) => CaseView(
          key: ValueKey(c.id),
          clinicalCase: c,
          onSubmit: (selected, ms) => ref
              .read(answerQueueProvider)
              .record(caseId: c.id, selected: selected, durationMs: ms),
          onNext: () => _close(context),
          nextLabel: 'Terminer',
        ),
      ),
    );
  }
}
