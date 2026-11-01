import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/network_utils.dart';
import '../../quiz/presentation/case_view.dart';
import '../data/review_repository.dart';
import 'review_controller.dart';

final reviewSummaryProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.read(reviewRepositoryProvider).dueCount(),
);

/// Tab "Révision": how many cards are due + start button.
class ReviewHomeScreen extends ConsumerWidget {
  const ReviewHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reviewSummaryProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Révision')),
      body: Center(
        child: summary.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyError(e), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(reviewSummaryProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
          data: (n) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$n', style: theme.textTheme.displayLarge),
              Text(n == 0
                  ? 'Rien à réviser pour le moment'
                  : n == 1
                      ? 'carte à réviser'
                      : 'cartes à réviser'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: n == 0
                    ? null
                    : () async {
                        await context.push('/review-session');
                        ref.invalidate(reviewSummaryProvider);
                      },
                child: const Text('Commencer la révision'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen review session (route /review-session).
class ReviewSessionScreen extends ConsumerWidget {
  const ReviewSessionScreen({super.key});

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/review');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewControllerProvider);
    final controller = ref.read(reviewControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Révision')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          text: friendlyError(e),
          actionLabel: 'Réessayer',
          onAction: () => ref.invalidate(reviewControllerProvider),
        ),
        data: (s) {
          if (s.cards.isEmpty) {
            return _Message(
              text: 'Aucune carte à réviser pour le moment.',
              actionLabel: 'Retour',
              onAction: () => _close(context),
            );
          }
          if (s.finished) {
            return _Message(
              text: 'Session terminée : ${s.correct} / ${s.answered} '
                  'bonnes réponses.',
              actionLabel: 'Terminer',
              onAction: () => _close(context),
            );
          }
          final card = s.current!;
          final isLast = s.index == s.cards.length - 1;
          return Column(
            children: [
              LinearProgressIndicator(value: s.index / s.cards.length),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${s.index + 1} / ${s.cards.length}'),
              ),
              Expanded(
                child: CaseView(
                  key: ValueKey(card.id),
                  clinicalCase: card,
                  onSubmit: controller.answer,
                  onNext: controller.next,
                  nextLabel: isLast ? 'Voir le résultat' : 'Carte suivante',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      );
}
