import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../models/animal_model.dart';
import '../providers/animal_providers.dart';
import '../providers/favorites_provider.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/action_button.dart';
import '../widgets/common/gradient_background.dart';
import '../widgets/swipe_card.dart';
import 'favorites_screen.dart';
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
  void _skip(int deckToken, AnimalImage swipedImage) {
    if (_isRefreshing) return;
    final removed = ref
        .read(animalImagesProvider.notifier)
        .removeTopImage(deckToken: deckToken, expectedTop: swipedImage);
    // 実際にスワイプが確定した（古い山札への操作として無視されていない）
    // 場合のみ鳴らす。HapticFeedback は Web では単なる no-op として無視
    // されるだけなので、kIsWeb によるプラットフォーム分岐は不要（#24）。
    if (removed) unawaited(HapticFeedback.lightImpact());
  }

  /// [swipedImage] は「実際にスワイプされたカード」そのもの。
  ///
  /// ここで山札の先頭を読み直してはいけない。スワイプ完了は 250ms 遅れて
  /// 通知されるため、その間に別の操作で山札が 1 枚進むと、先頭は
  /// 「スワイプされていない次のカード」に入れ替わっている。
  /// 通常の除去では [deckGeneration] が変わらず `removeTopImage` は
  /// 古いトークンを受け付けてしまうので、トークンだけでは防げない。
  /// カードを描画した時点の画像を呼び出し側から渡してもらうことで、
  /// 見ていない画像がお気に入りに入る事故を防ぐ。
  void _like(int deckToken, AnimalImage swipedImage) {
    if (_isRefreshing) return;
    // Undo でお気に入りを取り消すべきかは、このスワイプが実際に新規追加
    // したかどうかで決める。既にお気に入り済みの画像を再度「好き」しても
    // favoritesProvider.add は何もしないため、その場合に Undo で
    // お気に入りを消すと、このスワイプより前からのお気に入りを
    // 誤って消してしまう（#9）。
    final alreadyFavorite = ref
        .read(favoritesProvider.notifier)
        .isFavorite(swipedImage);
    final removed = ref
        .read(animalImagesProvider.notifier)
        .removeTopImage(
          deckToken: deckToken,
          expectedTop: swipedImage,
          undoRemovesFavorite: !alreadyFavorite,
        );
    // 古い操作で山札が変化しなかった場合は「好き」の通知もお気に入り登録もしない
    if (removed) {
      ref.read(favoritesProvider.notifier).add(swipedImage);
      _showLikedMessage();
      // Like は Skip よりわずかに強めのフィードバックにする（#24）。
      // Web では no-op になるだけなのでプラットフォーム分岐は不要。
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  /// 直前の 1 枚を戻す（Undo, #9）。
  ///
  /// スワイプ確定と違い、ユーザーが誤操作を取り消すための操作なので、
  /// 「戻った」ことが分かる程度の軽いフィードバックに留める
  /// （Like ほど強くしない）。戻せる履歴がない場合は Notifier 側で
  /// 何もせず null を返すので、ここでも何も鳴らさない。
  void _undo() {
    final result = ref.read(animalImagesProvider.notifier).undo();
    if (result == null) return;
    if (result.shouldUnfavorite) {
      ref.read(favoritesProvider.notifier).remove(result.image);
    }
    unawaited(HapticFeedback.lightImpact());
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

  void _goHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const StartScreen()),
    );
  }

  /// AppBar の「選び直す」をアイコンだけに畳むべきか
  ///
  /// タイトル（アイコン＋アプリ名）とお気に入りアイコン、そして
  /// 「選び直す」のラベルを横に並べると、狭い端末では入りきらない。
  /// 実効幅（論理幅 ÷ 文字倍率）で判定しているのは、文字サイズを
  /// 上げている利用者では同じ論理幅でもラベルが長くなるため。
  static bool _isCompactAppBar(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final effectiveWidth =
        mediaQuery.size.width / mediaQuery.textScaler.scale(1);
    return effectiveWidth < AppSizes.compactAppBarWidthThreshold;
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
    // Undo できる履歴があるか。imagesAsync を watch しているこの build() は
    // removeTopImage/undo が state を更新するたびに再実行されるので、
    // ここで都度読み直せば最新の状態に追従する（deckToken と同じ考え方）。
    final canUndo = ref.read(animalImagesProvider.notifier).canUndo;
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
          IconButton(
            tooltip: AppStrings.favoritesButtonTooltip,
            // ハートは「好き」を送るボタンと同じ Icons.favorite にすると
            // find.byIcon での判別がつかなくなる（UI 上も紛らわしい）ため、
            // 一覧を表す別のアイコンにする
            icon: const Icon(Icons.collections),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FavoritesScreen(),
                ),
              );
            },
          ),
          // お気に入りのアイコンが増えた分、狭い画面ではタイトルと
          // 「選び直す」のラベルが横幅を奪い合ってオーバーフローする。
          // 幅が足りないときはラベルを畳んでアイコンだけにする。
          // 文字サイズを大きくしている利用者でも同じことが起きるため、
          // 判定には textScaler を掛けた実効幅を使う。
          if (_isCompactAppBar(context))
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: IconButton(
                tooltip: AppStrings.homeButton,
                color: onGradient,
                icon: const Icon(Icons.home, size: AppSizes.iconHomeButton),
                onPressed: () => _goHome(context),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: onGradient),
                icon: const Icon(Icons.home, size: AppSizes.iconHomeButton),
                label: const Text(
                  AppStrings.homeButton,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _goHome(context),
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
                        onSwipeLeft: (image) => _skip(deckToken, image),
                        onSwipeRight: (image) => _like(deckToken, image),
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
                      onPressed: canUndo ? _undo : null,
                      icon: Icons.undo,
                      backgroundColor: context.colors.tertiary,
                      foregroundColor: context.colors.onTertiary,
                      label: AppStrings.undo,
                    ),
                    const SizedBox(width: AppSpacing.s24),
                    ActionButton(
                      // ボタン経由でも、押した瞬間の先頭カードを固定して渡す
                      onPressed: hasImage
                          ? () {
                              final top = imagesAsync.value?.firstOrNull;
                              if (top != null) _skip(deckToken, top);
                            }
                          : null,
                      icon: Icons.close,
                      backgroundColor: context.colors.error,
                      foregroundColor: context.colors.onError,
                      label: AppStrings.skip,
                    ),
                    const SizedBox(width: AppSpacing.s24),
                    ActionButton(
                      // ボタン経由でも、押した瞬間の先頭カードを固定して渡す
                      onPressed: hasImage
                          ? () {
                              final top = imagesAsync.value?.firstOrNull;
                              if (top != null) _like(deckToken, top);
                            }
                          : null,
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

  /// スワイプされたカードそのものを受け取るコールバック。
  ///
  /// 引数なしにして呼び出し側で山札の先頭を読み直すと、スワイプ完了の
  /// 通知が 250ms 遅れる間に山札が進んでいた場合、スワイプしていない
  /// 別のカードを処理してしまう。描画時点の画像をそのまま渡す。
  final void Function(AnimalImage image) onSwipeLeft;
  final void Function(AnimalImage image) onSwipeRight;

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
      onSwipeLeft: () => onSwipeLeft(image),
      onSwipeRight: () => onSwipeRight(image),
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
