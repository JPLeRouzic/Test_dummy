import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';

final questionCatalogProvider = FutureProvider<List<QuestionSummary>>((ref) async {
  if (!AppConfig.hasApiBaseUrl) return const [];
  final dio = ref.watch(dioProvider);
  final response = await dio.get<Map<String, dynamic>>('/cases');
  final items = response.data?['items'];
  if (items is! List) {
    throw const FormatException('Réponse API invalide : le champ items est absent.');
  }
  return items
      .map((item) => QuestionSummary.fromJson(item as Map<String, dynamic>))
      .toList();
});

class QuestionSummary {
  const QuestionSummary({
    required this.id,
    required this.title,
    this.category,
    this.locked = false,
  });

  factory QuestionSummary.fromJson(Map<String, dynamic> json) {
    return QuestionSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Question sans titre',
      category: json['category'] as String?,
      locked: json['locked'] as bool? ?? false,
    );
  }

  final int id;
  final String title;
  final String? category;
  final bool locked;
}

class QuestionCatalogScreen extends ConsumerWidget {
  const QuestionCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(questionCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Banque de questions')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Impossible de charger les questions',
          message: error.toString(),
          action: TextButton(
            onPressed: () => ref.invalidate(questionCatalogProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (items) {
          if (!AppConfig.hasApiBaseUrl) {
            return const _Message(
              icon: Icons.link_off,
              title: 'Serveur non configuré',
              message: 'Définissez API_BASE_URL au lancement pour connecter '
                  'la banque de questions à votre serveur PHP.',
            );
          }
          if (items.isEmpty) {
            return const _Message(
              icon: Icons.library_books_outlined,
              title: 'Aucune question disponible',
              message: 'Le serveur a répondu correctement, mais la banque est vide.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(questionCatalogProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: item.category == null ? null : Text(item.category!),
                    trailing: Icon(
                      item.locked ? Icons.lock_outline : Icons.chevron_right,
                    ),
                    onTap: item.locked
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('L’écran de question sera ajouté à l’étape suivante.'),
                              ),
                            );
                          },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
