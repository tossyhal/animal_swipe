import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  // AsyncNotifier の build() が初回 watch 時に走るため、
  // 画面側から明示的に初期読み込みを呼ぶ必要はない。

  void _showLikedMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.favorite, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                AppStrings.liked,
                style: TextStyle(fontFamily: AppStrings.fontFamily),
              ),
            ],
          ),
          backgroundColor: context.colors.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  void _skip() {
    ref.read(animalImagesProvider.notifier).removeTopImage();
  }

  void _like() {
    _showLikedMessage();
    ref.read(animalImagesProvider.notifier).removeTopImage();
  }

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(animalImagesProvider);
    // 追加読み込み中でも手元の画像は操作できるようにするため、
    // ローディング状態ではなく「表示できる画像があるか」でボタンを制御する
    final hasImage = imagesAsync.value?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, size: 21),
            SizedBox(width: 8),
            Text(
              AppStrings.appName,
              style: TextStyle(
                fontFamily: AppStrings.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.home, size: 19),
              label: const Text(
                AppStrings.homeButton,
                style: TextStyle(
                  fontFamily: AppStrings.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(builder: (_) => const StartScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              children: [
                const Text(
                  AppStrings.discoverTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: AppStrings.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  AppStrings.discoverSubtitle,
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: AppStrings.fontFamily,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: imagesAsync.when(
                      skipLoadingOnRefresh: false,
                      data: (images) {
                        if (images.isEmpty) return const _LoadingState();
                        return SwipeCard(
                          key: ValueKey(images.first.url),
                          image: images.first,
                          onSwipeLeft: _skip,
                          onSwipeRight: _like,
                        );
                      },
                      loading: () => const _LoadingState(),
                      error:
                          (error, stackTrace) => _LoadError(
                            onRetry: () {
                              ref.read(animalImagesProvider.notifier).reload();
                            },
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ActionButton(
                      onPressed: hasImage ? _skip : null,
                      icon: Icons.close,
                      backgroundColor: context.colors.error,
                      label: AppStrings.skip,
                    ),
                    const SizedBox(width: 44),
                    ActionButton(
                      onPressed: hasImage ? _like : null,
                      icon: Icons.favorite,
                      backgroundColor: context.colors.secondary,
                      label: AppStrings.like,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            AppStrings.loading,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: AppStrings.fontFamily,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 46,
                color: context.colors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                AppStrings.loadErrorTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppStrings.fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.loadErrorMessage,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
