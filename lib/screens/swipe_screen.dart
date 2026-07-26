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

  /// 再取得中は退場アニメーション中の古いカードが残っているため、
  /// そのカードへのスワイプ／タップを受け付けない
  bool get _isRefreshing => ref.read(animalImagesProvider).isLoading;

  /// [deckToken] はカードを表示した時点の山札世代。スワイプ完了は 250ms 遅れて
  /// 通知されるため、その間に山札が入れ替わっていないかを Notifier に照合させる。
  void _skip(int deckToken) {
    if (_isRefreshing) return;
    ref
        .read(animalImagesProvider.notifier)
        .removeTopImage(deckToken: deckToken);
  }

  void _like(int deckToken) {
    if (_isRefreshing) return;
    final removed = ref
        .read(animalImagesProvider.notifier)
        .removeTopImage(deckToken: deckToken);
    // 古い操作で山札が変化しなかった場合は「好き」の通知も出さない
    if (removed) _showLikedMessage();
  }

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(animalImagesProvider);
    // 再取得中は前回の値が AsyncLoading に保持されたままになる。
    // 画面はローディング表示なのにボタンだけ効いてしまわないよう、
    // 「いま表示中のカードがあるか」＝ 読み込み中でないこと も条件に含める。
    // 操作対象のカードがなければボタンは無効。
    final hasImage =
        !imagesAsync.isLoading && (imagesAsync.value?.isNotEmpty ?? false);
    // 表示中の山札の世代。カード操作にこれを持ち回らせる
    final deckToken = ref.read(animalImagesProvider.notifier).deckGeneration;

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
                        final top = images.first;
                        return SwipeCard(
                          key: ValueKey(top.url),
                          image: top,
                          onSwipeLeft: () => _skip(deckToken),
                          onSwipeRight: () => _like(deckToken),
                        );
                      },
                      loading: () => const _LoadingState(),
                      error: (error, stackTrace) => _LoadError(
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
                      onPressed: hasImage ? () => _skip(deckToken) : null,
                      icon: Icons.close,
                      backgroundColor: context.colors.error,
                      label: AppStrings.skip,
                    ),
                    const SizedBox(width: 44),
                    ActionButton(
                      onPressed: hasImage ? () => _like(deckToken) : null,
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 18),
          Text(
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
