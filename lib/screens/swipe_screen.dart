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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextButton.icon(
              icon: const Icon(Icons.home, color: Colors.white),
              label: const Text(
                'ホームに戻る',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'MPLUSRounded1c',
                ),
              ),
              onPressed: () {
                // スタート画面へ戻る
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const StartScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              bottom: 24.0,
            ),
            child: Column(
              children: [
                const Padding(padding: EdgeInsets.symmetric(vertical: 16.0)),
                // 画像表示エリア
                Expanded(
                  child:
                      images.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '読み込み中...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'MPLUSRounded1c',
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
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
                const SizedBox(height: 24),
                // 下部ボタン群
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      onPressed:
                          images.isEmpty
                              ? null
                              : () {
                                // × ボタン押下時：トップ画像を削除
                                ref
                                    .read(animalImagesProvider.notifier)
                                    .removeTopImage();
                              },
                      icon: Icons.close,
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      onPressed:
                          images.isEmpty
                              ? null
                              : () {
                                // お気に入り機能は後日実装予定
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('お気に入り機能は近日実装予定です'),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                // スワイプ処理と同様にトップ画像を削除
                                ref
                                    .read(animalImagesProvider.notifier)
                                    .removeTopImage();
                              },
                      icon: Icons.favorite,
                      backgroundColor: Colors.pink,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color backgroundColor,
  }) {
    final isEnabled = onPressed != null;

    return Material(
      elevation: isEnabled ? 4 : 0,
      color: Colors.transparent,
      shadowColor: backgroundColor.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: isEnabled ? backgroundColor : Colors.grey.shade300,
            shape: BoxShape.circle,
            boxShadow:
                isEnabled
                    ? [
                      BoxShadow(
                        color: backgroundColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
