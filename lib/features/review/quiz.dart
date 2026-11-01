import 'dart:math';

import 'content.dart';

/// Kinds of questions.
/// * [part]: a description, "which part is this?"
/// * [system]: a part name, "which system does it belong to?"
/// * [picture]: a highlighted part, "what is this?"
/// * [find]: a part name, "tap it on the body"
enum QuizKind { part, system, picture, find }

/// Rounds the Learn tab offers.
enum QuizMode { mixed, systems, find }

class QuizQuestion {
  const QuizQuestion({
    required this.kind,
    required this.subject,
    required this.options,
    required this.answer,
    this.key = '',
  });

  final QuizKind kind;

  /// The description of a part ([QuizKind.part]) or the name of a part
  /// ([QuizKind.system], [QuizKind.find]); empty for [QuizKind.picture].
  final String subject;
  final List<String> options;

  /// Index of the right option (-1 for [QuizKind.find]).
  final int answer;

  /// The part the question is about.
  final String key;
}

bool _leaks(PartContent c) {
  final name = c.name.toLowerCase();
  return name.length >= 3 && c.description.toLowerCase().contains(name);
}

/// Four options with the right one at a random place, or null when there are
/// not enough different wrong answers.
({List<String> options, int answer})? _options(
  String correct,
  Iterable<String> pool,
  Random random,
) {
  final wrong = pool.where((s) => s != correct).toSet().toList()..shuffle(random);
  if (wrong.length < 3) return null;
  final options = [...wrong.take(3), correct]..shuffle(random);
  return (options: options, answer: options.indexOf(correct));
}

/// Builds a round of questions from the texts that are already in the app, in
/// the language of [content]: "which part is this?" and "which system?".
///
/// [pictureKeys] are parts that can be shown as a picture ("what is the
/// highlighted part?"); some questions use them when given. With
/// [systemsOnly] every question asks for the body system.
List<QuizQuestion> buildQuiz(
  BodyContent content,
  Random random, {
  int count = 10,
  Set<String> pictureKeys = const {},
  bool systemsOnly = false,
}) {
  final keys = content.parts.keys
      .where((k) =>
          content[k]!.name.isNotEmpty && content[k]!.description.isNotEmpty)
      .toList()
    ..shuffle(random);
  if (keys.length < 8) return const [];

  final names = keys.map((k) => content[k]!.name).toList();
  final systems = content.systems.values.toList();
  final clean = keys.where((k) => !_leaks(content[k]!)).toList();
  final leaky = keys.where((k) => _leaks(content[k]!)).toList();
  final partOrder = [...clean, ...leaky];

  QuizQuestion? partQuestion(String k) {
    final c = content[k]!;
    final o = _options(c.name, names, random);
    if (o == null) return null;
    return QuizQuestion(
      kind: QuizKind.part,
      subject: c.description,
      options: o.options,
      answer: o.answer,
      key: k,
    );
  }

  QuizQuestion? systemQuestion(String k) {
    final c = content[k]!;
    final systemName = content.systems[c.system];
    if (systemName == null) return null;
    final o = _options(systemName, systems, random);
    if (o == null) return null;
    return QuizQuestion(
      kind: QuizKind.system,
      subject: c.name,
      options: o.options,
      answer: o.answer,
      key: k,
    );
  }

  QuizQuestion? pictureQuestion(String k) {
    final c = content[k]!;
    final o = _options(c.name, names, random);
    if (o == null) return null;
    return QuizQuestion(
      kind: QuizKind.picture,
      subject: '',
      options: o.options,
      answer: o.answer,
      key: k,
    );
  }

  final questions = <QuizQuestion>[];
  final used = <String>{};

  void fill(Iterable<String> order, QuizQuestion? Function(String) make, int upTo) {
    for (final k in order) {
      if (questions.length >= upTo) break;
      if (used.contains(k)) continue;
      final q = make(k);
      if (q != null) {
        questions.add(q);
        used.add(k);
      }
    }
  }

  if (systemsOnly) {
    fill(keys, systemQuestion, count);
  } else {
    final pictures = keys.where(pictureKeys.contains).toList();
    final pictureCount = pictures.isEmpty ? 0 : (count * 0.3).round();
    fill(pictures, pictureQuestion, pictureCount);
    fill(
      partOrder,
      partQuestion,
      questions.length + (count * (pictures.isEmpty ? 0.6 : 0.4)).round(),
    );
    fill(keys, systemQuestion, count);
    fill(partOrder, partQuestion, count);
  }
  questions.shuffle(random);
  return questions;
}

/// A round of "tap it on the body": [keys] are parts that can be found in the
/// 2D pictures.
List<QuizQuestion> buildFindQuiz(
  BodyContent content,
  Iterable<String> keys,
  Random random, {
  int count = 10,
}) {
  final list = keys.where((k) => content[k] != null).toList()..shuffle(random);
  return [
    for (final k in list.take(count))
      QuizQuestion(
        kind: QuizKind.find,
        subject: content.nameOf(k),
        options: const [],
        answer: -1,
        key: k,
      ),
  ];
}
