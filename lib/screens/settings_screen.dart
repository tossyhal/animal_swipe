import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'start_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView(
          children: [
            // 動物の種類を変更するための項目
            ListTile(
              leading: const Icon(Icons.pets),
              title: const Text('動物の種類を変更'),
              onTap: () {
                // StartScreenへ画面遷移（置き換え遷移）
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const StartScreen()),
                );
              },
            ),
            const Divider(),
            // アプリの情報を表示する項目
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('アプリについて'),
              onTap: () {
                // AboutDialogの表示
                showAboutDialog(
                  context: context,
                  applicationName: 'AnimalSwipe',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text('かわいい動物の画像をスワイプして癒されるアプリです。'),
                    const SizedBox(height: 8),
                    const Text('画像は各種APIから取得しています。'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
