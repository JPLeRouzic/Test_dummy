import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/section_heading.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MedQuest'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Bonjour !',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Organisez vos révisions et suivez votre progression.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Votre activité',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: _Metric(value: '—', label: 'Questions')),
                      Expanded(child: _Metric(value: '—', label: 'Révisions dues')),
                      Expanded(child: _Metric(value: '—', label: 'Série en cours')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Les statistiques apparaîtront lorsque votre compte sera connecté.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeading(title: 'Reprendre'),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.quiz_outlined,
            title: 'Banque de questions',
            subtitle: 'Parcourir les questions par matière et par item',
            onTap: () => context.go('/questions'),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.repeat,
            title: 'Révisions programmées',
            subtitle: 'Retrouver les questions à revoir',
            onTap: () => context.go('/revision'),
          ),
          const SizedBox(height: 24),
          const SectionHeading(title: 'À propos de cette version'),
          const SizedBox(height: 8),
          const Text(
            'Cette première base est volontairement minimale. Elle prépare '
            'la navigation et les couches techniques avant la connexion au '
            'serveur MedQuest.',
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
