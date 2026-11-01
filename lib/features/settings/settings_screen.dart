import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Langue'),
            subtitle: const Text('Français (version initiale)'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Serveur MedQuest'),
            subtitle: Text(
              AppConfig.hasApiBaseUrl ? AppConfig.apiBaseUrl : 'Non configuré',
            ),
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'MedQuest',
            applicationVersion: '0.1.0',
            applicationLegalese: 'Application de préparation aux examens médicaux.',
          ),
        ],
      ),
    );
  }
}
