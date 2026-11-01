import 'package:flutter/material.dart';

import '../domain/clinical_case.dart';

/// Reusable MCQ player: shows one case, lets the user select answers,
/// validates, then shows the correction. Used by both the catalog quiz
/// and the daily review session.
///
/// Give it a `key: ValueKey(case.id)` so its state resets between cases.
class CaseView extends StatefulWidget {
  const CaseView({
    super.key,
    required this.clinicalCase,
    required this.onSubmit,
    required this.onNext,
    this.nextLabel = 'Suivant',
  });

  final ClinicalCase clinicalCase;

  /// Called once, when the user validates. Record the answer here.
  final Future<void> Function(Set<int> selected, int durationMs) onSubmit;

  /// Called when the user taps the button shown after the correction.
  final VoidCallback onNext;
  final String nextLabel;

  @override
  State<CaseView> createState() => _CaseViewState();
}

class _CaseViewState extends State<CaseView> {
  final _selected = <int>{};
  final _watch = Stopwatch()..start();
  bool _submitted = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    _watch.stop();
    try {
      await widget.onSubmit(Set.of(_selected), _watch.elapsedMilliseconds);
      if (mounted) setState(() => _submitted = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(int id, bool? value) {
    if (_submitted) return; // locked after validation
    setState(() {
      if (value == true) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.clinicalCase;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (c.category != null)
                Text(c.category!, style: theme.textTheme.labelLarge),
              Text(c.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(c.statement, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              Text('Sélectionnez toutes les réponses exactes.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final choice in c.choices) _choiceTile(choice, theme),
              if (_submitted) _feedback(c, theme),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: _submitted
                  ? FilledButton(
                      onPressed: widget.onNext,
                      child: Text(widget.nextLabel),
                    )
                  : FilledButton(
                      onPressed: _selected.isEmpty || _busy ? null : _submit,
                      child: const Text('Valider'),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _choiceTile(Choice choice, ThemeData theme) {
    final selected = _selected.contains(choice.id);
    Color? color;
    Widget? marker;
    if (_submitted) {
      if (choice.isCorrect) {
        color = Colors.green.withValues(alpha: 0.15);
        marker = Icon(Icons.check_circle, color: Colors.green.shade700);
      } else if (selected) {
        color = theme.colorScheme.errorContainer;
        marker = Icon(Icons.cancel, color: theme.colorScheme.error);
      }
    }
    return Card(
      color: color,
      child: CheckboxListTile(
        value: selected,
        onChanged: (v) => _toggle(choice.id, v),
        title: Text(choice.text),
        secondary: marker,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _feedback(ClinicalCase c, ThemeData theme) {
    final ok = c.isCorrect(_selected);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: ok
          ? Colors.green.withValues(alpha: 0.15)
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ok ? 'Bonne réponse' : 'Réponse incorrecte',
              style: theme.textTheme.titleMedium,
            ),
            if (c.explanation != null) ...[
              const SizedBox(height: 8),
              Text(c.explanation!),
            ],
          ],
        ),
      ),
    );
  }
}
