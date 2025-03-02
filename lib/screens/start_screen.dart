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
      {'id': 'cat', 'name': 'ねこ', 'icon': Icons.pets, 'emoji': '🐱'},
      {'id': 'dog', 'name': 'いぬ', 'icon': Icons.pets, 'emoji': '🐶'},
    ];

    return Scaffold(
      // Scaffoldに直接背景色を設定して画面全体をカバー
      backgroundColor: Colors.transparent,
      body: Container(
        // 画面全体をカバーするコンテナ
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        // SafeAreaをラップ
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 使用可能な高さを取得
              final availableHeight = constraints.maxHeight;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: availableHeight),
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // アプリタイトル
                        const Text(
                          'Animal Swipe',
                          style: TextStyle(
                            fontSize: 50,
                            fontFamily: 'MPLUSRounded1c',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 5.0,
                                color: Colors.black26,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          // 使用可能な高さの20%分のスペースを確保
                          height: availableHeight * 0.15,
                        ),
                        // 動物選択部分
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    '表示する動物を選択してください',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'MPLUSRounded1c',
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // グリッドで動物タイプを表示
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 1.2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  itemCount: availableTypes.length,
                                  itemBuilder: (context, index) {
                                    final type = availableTypes[index];
                                    final bool isSelected = selectedTypes
                                        .contains(type['id']);

                                    return InkWell(
                                      onTap: () {
                                        // 選択状態の切り替え
                                        ref
                                            .read(
                                              selectedAnimalTypesProvider
                                                  .notifier,
                                            )
                                            .selectType(
                                              type['id'] as String,
                                              !isSelected,
                                            );
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? Theme.of(
                                                    context,
                                                  ).colorScheme.primaryContainer
                                                  : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  isSelected
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.4,
                                                          )
                                                      : Colors.grey.withValues(
                                                        alpha: 0.2,
                                                      ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  type['emoji'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 48,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  type['name'] as String,
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontFamily:
                                                        'MPLUSRounded1c',
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        isSelected
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .onPrimaryContainer
                                                            : Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (isSelected)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
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
                                                  .read(
                                                    selectedAnimalTypesProvider
                                                        .notifier,
                                                  )
                                                  .saveSelectedTypes();
                                              // 画面遷移：SwipeScreenへ
                                              Navigator.of(
                                                context,
                                              ).pushReplacement(
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                          const SwipeScreen(),
                                                ),
                                              );
                                            },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Colors.grey.shade300,
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      'はじめる',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontFamily: 'MPLUSRounded1c',
                                        fontWeight: FontWeight.bold,
                                        color:
                                            selectedTypes.isEmpty
                                                ? Colors.grey.shade500
                                                : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          // 使用可能な高さの20%分のスペースを確保
                          height: availableHeight * 0.15,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
