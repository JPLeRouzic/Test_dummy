import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/network_utils.dart';
import '../data/quiz_repository.dart';
import '../domain/clinical_case.dart';

final caseListProvider = FutureProvider.autoDispose<List<CaseSummary>>(
  (ref) => ref.read(quizRepositoryProvider).listCases(),
);

/// Minimal catalog (first page only). Add category filters and pagination
/// when you build the dedicated `catalog` feature.
class CaseListScreen extends ConsumerWidget {
  const CaseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(caseListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cas cliniques')),
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
                  onPressed: () => ref.invalidate(caseListProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(caseListProvider.future),
          child: items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Aucun cas disponible.')),
                ])
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return ListTile(
                      title: Text(c.title),
                      subtitle: c.category == null ? null : Text(c.category!),
                      trailing: Icon(
                        c.locked ? Icons.lock_outline : Icons.chevron_right,
                      ),
                      onTap: () => context.push('/case/${c.id}'),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
