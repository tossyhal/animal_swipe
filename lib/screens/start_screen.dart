import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/animal_providers.dart';
import 'swipe_screen.dart';

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 選択中の動物タイプを監視
    final selectedTypes = ref.watch(selectedAnimalTypesProvider);

    // 利用可能な動物タイプ一覧
    final List<Map<String, dynamic>> availableTypes = [
      {'id': 'cat', 'name': 'ねこ', 'icon': Icons.pets},
      {'id': 'dog', 'name': 'いぬ', 'icon': Icons.pets},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('AnimalSwipe')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '表示する動物を選択してください',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'MPLUSRounded1c',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // グリッドで動物タイプを表示
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: availableTypes.length,
                  itemBuilder: (context, index) {
                    final type = availableTypes[index];
                    final bool isSelected = selectedTypes.contains(type['id']);

                    return InkWell(
                      onTap: () {
                        // 選択状態の切り替え
                        ref
                            .read(selectedAnimalTypesProvider.notifier)
                            .selectType(type['id'] as String, !isSelected);
                      },
                      child: Card(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 64,
                                color:
                                    isSelected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                        : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                type['name'] as String,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontFamily: 'MPLUSRounded1c',
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                          : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // 「始める」ボタン（選択がない場合は無効）
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      selectedTypes.isEmpty
                          ? null
                          : () {
                            // 選択状態の保存
                            ref
                                .read(selectedAnimalTypesProvider.notifier)
                                .saveSelectedTypes();
                            // 画面遷移：SwipeScreenへ
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const SwipeScreen(),
                              ),
                            );
                          },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    '始める',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'MPLUSRounded1c',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
