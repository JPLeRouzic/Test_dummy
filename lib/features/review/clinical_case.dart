class Choice {
  const Choice({required this.id, required this.text, required this.isCorrect});

  factory Choice.fromJson(Map<String, dynamic> j) => Choice(
        id: j['id'] as int,
        text: j['text'] as String,
        isCorrect: j['is_correct'] as bool,
      );

  final int id;
  final String text;
  final bool isCorrect;

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'is_correct': isCorrect};
}

class ClinicalCase {
  const ClinicalCase({
    required this.id,
    required this.title,
    required this.statement,
    required this.choices,
    this.category,
    this.explanation,
  });

  factory ClinicalCase.fromJson(Map<String, dynamic> j) => ClinicalCase(
        id: j['id'] as int,
        title: j['title'] as String,
        category: j['category'] as String?,
        statement: j['statement'] as String,
        explanation: j['explanation'] as String?,
        choices: (j['choices'] as List)
            .map((e) => Choice.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String title;
  final String? category;
  final String statement;
  final String? explanation;
  final List<Choice> choices;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'statement': statement,
        'explanation': explanation,
        'choices': choices.map((c) => c.toJson()).toList(),
      };

  Set<int> get correctIds => {
        for (final c in choices)
          if (c.isCorrect) c.id,
      };

  /// Strict scoring: the selection must match the correct set exactly.
  /// (The server recomputes its own grade; this is only for instant feedback.)
  bool isCorrect(Set<int> selected) =>
      selected.length == correctIds.length && selected.containsAll(correctIds);
}

/// Lightweight item for the catalog list.
class CaseSummary {
  const CaseSummary({
    required this.id,
    required this.title,
    this.category,
    this.locked = false,
  });

  factory CaseSummary.fromJson(Map<String, dynamic> j) => CaseSummary(
        id: j['id'] as int,
        title: j['title'] as String,
        category: j['category'] as String?,
        locked: (j['locked'] as bool?) ?? false,
      );

  final int id;
  final String title;
  final String? category;

  /// True when the case needs a subscription the user does not have.
  final bool locked;
}
