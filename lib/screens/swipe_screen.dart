import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import '../providers/animal_providers.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/action_button.dart';
import '../widgets/common/gradient_background.dart';
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(AppConstants.appBarHeight),
        child: Container(
          padding: const EdgeInsets.only(
            top: AppConstants.appBarTopPadding,
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              Container(
                margin: const EdgeInsets.only(
                  right: AppConstants.paddingMedium,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: AppConstants.opacityMediumLow,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusExtraLarge,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: AppConstants.opacityExtraLow,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  icon: const Icon(Icons.home, color: Colors.black87),
                  label: const Text(
                    AppStrings.homeButton,
                    style: TextStyle(
                      fontSize: AppConstants.fontSizeSmall,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppStrings.fontFamily,
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
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppConstants.paddingMedium,
              left: AppConstants.paddingMedium,
              right: AppConstants.paddingMedium,
              bottom: AppConstants.paddingLarge,
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppConstants.paddingMedium,
                  ),
                ),
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
                                const SizedBox(
                                  height: AppConstants.paddingMedium,
                                ),
                                const Text(
                                  AppStrings.loading,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: AppStrings.fontFamily,
                                    fontSize: AppConstants.fontSizeMedium,
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
                const SizedBox(height: AppConstants.paddingLarge),
                // 下部ボタン群
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ActionButton(
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
                      backgroundColor: context.colors.error,
                    ),
                    const SizedBox(width: AppConstants.paddingLarge),
                    ActionButton(
                      onPressed:
                          images.isEmpty
                              ? null
                              : () {
                                // お気に入り機能は後日実装予定
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      AppStrings.favoriteFeatureComingSoon,
                                    ),
                                    backgroundColor: context.colors.primary,
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.borderRadiusSmall,
                                      ),
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
}
