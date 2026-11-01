import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quiz/domain/clinical_case.dart';
import '../data/review_repository.dart';

class ReviewSession {
  const ReviewSession({
    required this.cards,
    this.index = 0,
    this.correct = 0,
    this.answered = 0,
  });

  final List<ClinicalCase> cards;
  final int index; // card currently shown
  final int correct;
  final int answered;

  bool get finished => index >= cards.length;
  ClinicalCase? get current => finished ? null : cards[index];

  ReviewSession copyWith({int? index, int? correct, int? answered}) =>
      ReviewSession(
        cards: cards,
        index: index ?? this.index,
        correct: correct ?? this.correct,
        answered: answered ?? this.answered,
      );
}

class ReviewController extends AutoDisposeAsyncNotifier<ReviewSession> {
  @override
  Future<ReviewSession> build() async {
    final cards = await ref.read(reviewRepositoryProvider).loadDue();
    return ReviewSession(cards: cards);
  }

  /// Records the answer for the current card (stays on the card so the
  /// user can read the correction).
  Future<void> answer(Set<int> selected, int durationMs) async {
    final s = state.requireValue;
    final card = s.current!;
    await ref
        .read(reviewRepositoryProvider)
        .recordAnswer(card, selected, durationMs);
    state = AsyncData(s.copyWith(
      answered: s.answered + 1,
      correct: s.correct + (card.isCorrect(selected) ? 1 : 0),
    ));
  }

  void next() {
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(s.copyWith(index: s.index + 1));
  }
}

final reviewControllerProvider =
    AsyncNotifierProvider.autoDispose<ReviewController, ReviewSession>(
  ReviewController.new,
);
