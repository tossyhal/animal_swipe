import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../models/animal_model.dart';
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
    // SnackBar の背景は secondary なので、前景は onSecondary
    final onSnackBar = context.colors.onSecondary;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.favorite,
                color: onSnackBar,
                size: AppSizes.iconInline,
              ),
              const SizedBox(width: AppSpacing.s10),
              Text(AppStrings.liked, style: TextStyle(color: onSnackBar)),
            ],
          ),
          backgroundColor: context.colors.secondary,
          behavior: SnackBarBehavior.floating,
          duration: AppDuration.likedSnackBar,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.snackBar),
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

  /// 画面に描画中のスタック（先頭 3 枚）よりさらに先の画像を、
  /// スワイプで実際にスタックへ入ってくる前にデコードしておく。
  ///
  /// スタック内（先頭〜3 枚目）は Widget ツリーに乗った時点で
  /// `Image.network` が自ら読み込みを始めるため、ここで明示的に
  /// `precacheImage` するのはスタックの外側（4 枚目以降）だけでよい。
  void _preloadUpcoming(List<AnimalImage> images) {
    if (images.length <= 3) return;
    final upcoming = images.skip(3).take(AppSizes.cardStackPreloadAhead);
    // SwipeCard の Image.network と同じ cacheHeight を使い、同じ
    // ImageProvider（ResizeImage でラップされたもの）を組み立てる（#7）。
    //
    // image.url をそのまま使う（＝ AnimalSource が組み立てた URL を
    // 再構築しない）だけでは足りない。SwipeCard 側は cacheHeight を
    // 指定しており、Image.network は内部で
    // `ResizeImage.resizeIfNeeded(..., cacheHeight, NetworkImage(url))` に
    // 差し替える。ImageCache のキーはこのラップ後の値で決まるため、
    // ここで素の NetworkImage を precache しても表示側とは別キー扱いに
    // なり、先読みが丸ごと無駄になって表示時に同じ画像を 2 回取得して
    // しまう。そのため cardImageCacheHeight を通じて同じ高さを使い、
    // ResizeImage を明示的に組み立てて渡す。
    final cacheHeight = cardImageCacheHeight(context);
    for (final image in upcoming) {
      final ImageProvider provider = cacheHeight != null
          ? ResizeImage(NetworkImage(image.url), height: cacheHeight)
          : NetworkImage(image.url);
      // 失敗しても画面の表示自体には影響しない先読みなので、
      // エラーはここで握りつぶし、UI 側の errorBuilder に任せる。
      unawaited(
        precacheImage(provider, context, onError: (error, stackTrace) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(animalImagesProvider);
    // 山札が更新されるたびに、スタックの外側にいる次の画像を先読みする
    ref.listen<AsyncValue<List<AnimalImage>>>(animalImagesProvider, (
      previous,
      next,
    ) {
      final images = next.value;
      if (images != null) _preloadUpcoming(images);
    });
    // 再取得中は前回の値が AsyncLoading に保持されたままになる。
    // 画面はローディング表示なのにボタンだけ効いてしまわないよう、
    // 「いま表示中のカードがあるか」＝ 読み込み中でないこと も条件に含める。
    // 操作対象のカードがなければボタンは無効。
    final hasImage =
        !imagesAsync.isLoading && (imagesAsync.value?.isNotEmpty ?? false);
    // 表示中の山札の世代。カード操作にこれを持ち回らせる
    final deckToken = ref.read(animalImagesProvider.notifier).deckGeneration;
    // AppBar / GradientBackground はどちらも primary ベースなので前景は onPrimary
    final onGradient = context.colors.onPrimary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.colors.primary,
        foregroundColor: onGradient,
        titleSpacing: AppSpacing.s20,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, size: AppSizes.iconAppBar),
            SizedBox(width: AppSpacing.s8),
            Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: AppSizes.font18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: onGradient),
              icon: const Icon(Icons.home, size: AppSizes.iconHomeButton),
              label: const Text(
                AppStrings.homeButton,
                style: TextStyle(fontWeight: FontWeight.bold),
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s18,
              AppSpacing.s18,
              AppSpacing.s18,
              AppSpacing.s22,
            ),
            child: Column(
              children: [
                Text(
                  AppStrings.discoverTitle,
                  style: TextStyle(
                    color: onGradient,
                    fontSize: AppSizes.font22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  AppStrings.discoverSubtitle,
                  style: TextStyle(
                    color: onGradient.withValues(
                      alpha: AppOpacity.onGradientMuted,
                    ),
                    fontSize: AppSizes.font13,
                  ),
                ),
                const SizedBox(height: AppSpacing.s14),
                Expanded(
                  child: imagesAsync.when(
                    skipLoadingOnRefresh: false,
                    data: (images) {
                      if (images.isEmpty) return const _LoadingState();
                      return _CardStack(
                        images: images,
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
                const SizedBox(height: AppSpacing.s18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ActionButton(
                      onPressed: hasImage ? () => _skip(deckToken) : null,
                      icon: Icons.close,
                      backgroundColor: context.colors.error,
                      foregroundColor: context.colors.onError,
                      label: AppStrings.skip,
                    ),
                    const SizedBox(width: AppSpacing.s44),
                    ActionButton(
                      onPressed: hasImage ? () => _like(deckToken) : null,
                      icon: Icons.favorite,
                      backgroundColor: context.colors.secondary,
                      foregroundColor: context.colors.onSecondary,
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

/// 山札の先頭 3 枚を [Stack] で重ねて「束」に見せるカードスタック。
///
/// 次の 2 枚を最初から Widget ツリーに乗せておくことで、スワイプ完了直後に
/// `Image.network` の読み込み待ちでスピナーが出る問題（#6）を解消する。
/// 先頭以外は [IgnorePointer] でジェスチャを受けない。
class _CardStack extends StatelessWidget {
  final List<AnimalImage> images;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  static const int _visibleCount = 3;

  const _CardStack({
    required this.images,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  /// 表示対象の先頭 [_visibleCount] 枚。
  ///
  /// 重複排除はしない。ランダム画像 API は同じ URL を連続して返し得るが、
  /// 山札から取り除かれるのは常に先頭の 1 枚だけなので、ここで間引くと
  /// 「次に出るカード」の予告が実際の山札とずれてしまう。
  List<AnimalImage> get _visible =>
      images.take(_visibleCount).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Stack(
      alignment: Alignment.center,
      // 奥（末尾）から積むことで、先頭カード（index 0）が最前面になる
      children: [
        for (var i = visible.length - 1; i >= 0; i--) _layer(visible[i], i),
      ],
    );
  }

  Widget _layer(AnimalImage image, int index) {
    // キーは URL ではなく [ObjectKey]（＝ identical 比較）を使う。
    //
    // SwipeCard は _dragOffset という進行中のドラッグ状態を持つため、
    // 山札が 1 枚進んだら先頭スロットの Element を作り直させる必要がある。
    // URL をキーにすると、API が同じ URL を連続で返したときに
    // キーが変わらず、前のカードのドラッグ状態が引き継がれてしまう。
    // 山札の各要素はパース時に生成された別インスタンスなので、
    // ObjectKey なら URL が重複していても 1 枚ずつ別物として扱える。
    final card = SwipeCard(
      key: ObjectKey(image),
      image: image,
      onSwipeLeft: onSwipeLeft,
      onSwipeRight: onSwipeRight,
    );

    if (index == 0) return card;

    final scale = index == 1
        ? AppSizes.cardStackScaleSecond
        : AppSizes.cardStackScaleThird;
    final offsetY = index == 1
        ? AppSizes.cardStackOffsetSecond
        : AppSizes.cardStackOffsetThird;

    // 背面のカードは「次に来る絵」を覗かせるための装飾でしかない。
    // IgnorePointer が外すのはポインタ関連のセマンティクスだけで、
    // 配下のテキストは読み上げ対象に残るため、ExcludeSemantics で
    // 明示的に除外する。そうしないとスクリーンリーダーが
    // 手前のカードに続けて 2 枚目・3 枚目の説明まで読み上げてしまう。
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(0, offsetY),
          child: Transform.scale(scale: scale, child: card),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    // GradientBackground（primary ベース）の上に乗るので前景は onPrimary
    final onGradient = context.colors.onPrimary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: AppSizes.loadingIndicator,
            height: AppSizes.loadingIndicator,
            child: CircularProgressIndicator(
              color: onGradient,
              strokeWidth: AppSizes.loadingIndicatorStroke,
            ),
          ),
          const SizedBox(height: AppSpacing.s18),
          Text(
            AppStrings.loading,
            textAlign: TextAlign.center,
            style: TextStyle(color: onGradient, fontSize: AppSizes.font15),
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
          color: context.colors.surface.withValues(alpha: AppOpacity.panel),
          borderRadius: BorderRadius.circular(AppRadius.loadError),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: AppSizes.iconLoadError,
                color: context.colors.primary,
              ),
              const SizedBox(height: AppSpacing.s16),
              const Text(
                AppStrings.loadErrorTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.font18,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                AppStrings.loadErrorMessage,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
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
