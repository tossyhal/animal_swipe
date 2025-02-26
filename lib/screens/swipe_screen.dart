import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/animal_providers.dart';
import '../widgets/swipe_card.dart';
import 'start_screen.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  @override
  void initState() {
    super.initState();
    // 画面が描画された後に初期画像を読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(animalImagesProvider.notifier).loadInitialImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    // プロバイダーから動物画像リストを取得
    final images = ref.watch(animalImagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimalSwipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pets),
            tooltip: '動物の種類を変更',
            onPressed: () {
              // スタート画面へ戻る
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const StartScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 画像表示エリア
              Expanded(
                child:
                    images.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : SwipeCard(
                          image: images.first,
                          onSwipeLeft: () {
                            // 左スワイプ時の処理：トップ画像をリストから削除
                            ref
                                .read(animalImagesProvider.notifier)
                                .removeTopImage();
                          },
                          onSwipeRight: () {
                            // 右スワイプ時の処理：トップ画像をリストから削除
                            ref
                                .read(animalImagesProvider.notifier)
                                .removeTopImage();
                          },
                        ),
              ),
              const SizedBox(height: 16),
              // 下部ボタン群
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        images.isEmpty
                            ? null
                            : () {
                              // × ボタン押下時：トップ画像を削除
                              ref
                                  .read(animalImagesProvider.notifier)
                                  .removeTopImage();
                            },
                    iconSize: 32,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite),
                    onPressed:
                        images.isEmpty
                            ? null
                            : () {
                              // お気に入り機能は後日実装予定
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('お気に入り機能は近日実装予定です'),
                                ),
                              );
                              // スワイプ処理と同様にトップ画像を削除
                              ref
                                  .read(animalImagesProvider.notifier)
                                  .removeTopImage();
                            },
                    iconSize: 32,
                    color: Colors.pink,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
