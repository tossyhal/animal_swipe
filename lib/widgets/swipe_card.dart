import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../models/animal_model.dart';
import '../services/animal_source.dart' show kCatImageHeight;
import '../theme/theme_extensions.dart';

/// [cardImageCacheHeight] が高さを丸め込むバケツの単位（デバイス px）。
///
/// ウィンドウリサイズ・分割画面・回転のたびに 1px 単位で
/// `ResizeImage` の `ImageCache` キーが変わると、表示中の3枚が総入れ替え
/// で再フェッチされる「リクエストの嵐」が起きる（#7）。この単位で
/// 高さを切り上げてバケツ化することで、近い高さのビューポートは
/// 同じキーを共有し、リサイズのたびにキーがずれるのを防ぐ。
const int kCardImageCacheHeightBucket = 256;

/// カード画像の `cacheHeight`（デコード解像度）に使う縦幅を計算する（#7）。
///
/// 表示は `BoxFit.cover` のポートレートなペインのため、リサイズの基準は
/// 幅ではなく高さ（cover でクロップされずに残る側）にする必要がある
/// （[kCatImageHeight] のコメント参照。横長画像を幅基準でリクエストすると
/// 高さが足りずアップスケールされ画質が劣化していた）。
///
/// スワイプ画面の先読み（[SwipeScreen] 内の `precacheImage`）と実際の表示
/// （本ファイルの [Image.network]）の両方がこの関数を経由することで、
/// `ResizeImage` でラップされた `ImageProvider` の `ImageCache` キーが
/// 完全に一致し、先読みした画像が表示時に取り直されてしまう二重フェッチ
/// を防ぐ。
///
/// カードの実測レイアウト高さではなく画面高さを基準にしているのは、
/// 先読み時点ではまだレイアウトされていない先のカードについて
/// 実測値を再現できないため（先読みと表示のどちらで呼んでも同じ整数を
/// 返せることを優先する）。カードはほぼ画面いっぱいに表示されるので、
/// 画面高さを使っても実用上問題はなく、多少大きめにデコードされるだけの
/// 安全側の近似になる。
///
/// [kCardImageCacheHeightBucket] px 単位に切り上げてバケツ化した上で、
/// 取得画像自体の高さ（[kCatImageHeight]）でクランプする。実際に届く
/// バイト列より大きくデコードしても無意味なため。
///
/// レイアウトが確定できない（`MediaQuery.size` が 0 など）場合は
/// `null` を返し、リサイズなし（原寸デコード）にフォールバックする。
int? cardImageCacheHeight(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final rawHeight = mediaQuery.size.height * mediaQuery.devicePixelRatio;
  if (rawHeight <= 0) return null;
  final bucketed =
      (rawHeight / kCardImageCacheHeightBucket).ceil() *
      kCardImageCacheHeightBucket;
  return math.min(bucketed, kCatImageHeight);
}

class SwipeCard extends StatefulWidget {
  final AnimalImage image;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const SwipeCard({
    super.key,
    required this.image,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<Offset>? _offsetAnimation;
  VoidCallback? _animationComplete;
  // ドラッグ量は毎フレーム更新されるため、setState を使うと
  // Image / Card を含む巨大なツリー全体が再構築されカクつきの原因になる。
  // ValueNotifier に切り出し、購読する ValueListenableBuilder だけを
  // 再描画することで、カード本体は一度だけ build すれば済むようにする。
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );
  Offset _dragStartPosition = Offset.zero;
  bool _isDragging = false;
  bool _isTap = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: AppDuration.cardSwipe)
          ..addListener(() {
            final animation = _offsetAnimation;
            if (animation != null && mounted) {
              _dragOffsetNotifier.value = animation.value;
            }
          })
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed) return;
            final callback = _animationComplete;
            _animationComplete = null;
            callback?.call();
            // callback（onSwipeLeft/Right）がカードを取り除き、この
            // State を破棄させ得るため、mounted 確認より前に
            // ValueNotifier を触ってはいけない。
            if (mounted) {
              _dragOffsetNotifier.value = Offset.zero;
              // ドラッグ中かどうかは Transform.scale のスケールにしか
              // 影響しないうえ、アニメーション完了時にしか変化しないので、
              // ここは setState のままで全体を再構築しても頻度上問題ない。
              setState(() => _isDragging = false);
            }
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  // パンジェスチャー開始時の処理
  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _isTap = true;
      _dragStartPosition = details.globalPosition;
    });
  }

  // パンジェスチャー更新時の処理
  void _onPanUpdate(DragUpdateDetails details) {
    // 移動距離が閾値を超えたら、単純なタップではないとマーク
    if ((details.globalPosition - _dragStartPosition).distance > 10) {
      _isTap = false;
    }

    final rawOffset = details.globalPosition - _dragStartPosition;
    _dragOffsetNotifier.value = Offset(rawOffset.dx, rawOffset.dy * 0.18);
  }

  // パンジェスチャー終了時の処理
  void _onPanEnd(DragEndDetails details) {
    if (_isTap) {
      setState(() => _isDragging = false);
      _dragOffsetNotifier.value = Offset.zero;
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // 距離だけでなくフリック速度も考慮し、片手でも軽く操作できるようにする
    const thresholdFraction = 0.22;
    final threshold = screenWidth * thresholdFraction;
    final horizontalVelocity = details.velocity.pixelsPerSecond.dx;
    final isFastHorizontalFlick =
        horizontalVelocity.abs() > 700 &&
        horizontalVelocity.abs() >
            details.velocity.pixelsPerSecond.dy.abs() * 1.2;
    final dragOffset = _dragOffsetNotifier.value;

    if (dragOffset.dx.abs() > threshold || isFastHorizontalFlick) {
      // 横方向のスワイプが閾値を超えた場合
      final swipedRight = dragOffset.dx == 0
          ? horizontalVelocity > 0
          : dragOffset.dx > 0;
      if (swipedRight) {
        // 右スワイプの場合
        _animateCardOut(screenWidth * 1.5, 0, widget.onSwipeRight);
      } else {
        // 左スワイプの場合
        _animateCardOut(-screenWidth * 1.5, 0, widget.onSwipeLeft);
      }
    } else {
      // 閾値未満の場合はカードを中央に戻すアニメーションを実行
      _animateCardBack();
    }
  }

  // スワイプが成功した場合、カードを画面外へアニメーションさせる処理
  void _animateCardOut(
    double targetX,
    double targetY,
    VoidCallback onComplete,
  ) {
    final startOffset = _dragOffsetNotifier.value;
    final endOffset = Offset(targetX, targetY);

    _offsetAnimation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _animationComplete = onComplete;
    _controller.forward(from: 0);
  }

  // スワイプ失敗時にカードを中央に戻すアニメーション
  void _animateCardBack() {
    final startOffset = _dragOffsetNotifier.value;
    final endOffset = Offset.zero;

    _offsetAnimation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _animationComplete = null;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = _isDragging ? 0.975 : 1.0;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      // Transform 部分だけを ValueListenableBuilder で包み、
      // カード本体（child）は一度だけ build して使い回す。
      child: ValueListenableBuilder<Offset>(
        valueListenable: _dragOffsetNotifier,
        builder: (context, dragOffset, child) {
          // 回転角度 = dragOffset.dx / 800
          final rotationAngle = dragOffset.dx / 900;
          return Transform.translate(
            offset: dragOffset,
            child: Transform.rotate(
              angle: rotationAngle,
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
        child: Stack(
          children: [
            Card(
              elevation: AppSizes.elevationSwipeCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.swipeCard),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  children: [
                    Expanded(
                      child: _CardImage(
                        url: widget.image.url,
                        cacheHeight: cardImageCacheHeight(context),
                        colors: colors,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(AppRadius.swipeCard),
                          bottomRight: Radius.circular(AppRadius.swipeCard),
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.image.description != null)
                            Text(
                              widget.image.description!,
                              style: TextStyle(
                                fontSize: AppSizes.font18,
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.s4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8,
                                  vertical: AppSpacing.s4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.chip,
                                  ),
                                ),
                                child: Text(
                                  // 表示は従来どおり英字大文字（CAT / DOG）。
                                  // 列挙子名ではなく安定した id を使う。
                                  widget.image.type.id.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: AppSizes.font14,
                                    fontWeight: FontWeight.w500,
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // スワイプ方向に応じたアイコン表示
            // （ドラッグ量が swipeBadgeRevealDistance を超えた場合）
            // Transform とは別の ValueListenableBuilder に分離し、
            // バッジの表示切り替えが Transform 側の再構築を巻き込まない
            // ようにする。
            ValueListenableBuilder<Offset>(
              valueListenable: _dragOffsetNotifier,
              builder: (context, dragOffset, _) {
                if (dragOffset.dx.abs() <= AppSizes.swipeBadgeRevealDistance) {
                  return const SizedBox.shrink();
                }
                final isLiked = dragOffset.dx > 0;
                return Positioned(
                  top: AppSpacing.s20,
                  right: isLiked ? AppSpacing.s20 : null,
                  left: isLiked ? null : AppSpacing.s20,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: (isLiked ? colors.secondary : colors.error)
                          .withValues(alpha: AppOpacity.swipeBadge),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isLiked ? colors.secondary : colors.error)
                              .withValues(alpha: AppOpacity.swipeBadgeGlow),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.close,
                      color: isLiked ? colors.onSecondary : colors.onError,
                      size: AppSizes.iconSwipeBadge,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// スワイプカードの画像本体（読み込み中・エラー時の表示を含む）
///
/// [SwipeCard.build] から切り出したもの。
class _CardImage extends StatelessWidget {
  final String url;
  final int? cacheHeight;
  final ColorScheme colors;

  const _CardImage({
    required this.url,
    required this.cacheHeight,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ここには以前 Hero が置かれていたが、遷移先に
        // 対応する Hero が無く何も起きていなかった。
        // 一方でカードスタック（#6）により同じ画像が
        // 同時に複数枚描かれ得るため、tag 衝突で
        // 「multiple heroes that share the same tag」
        // アサーションを踏むリスクだけが残っていた。
        // 全画面拡大表示を入れる時に改めて導入する。
        //
        // cacheHeight（[cardImageCacheHeight]）は、原寸のままデコードされて
        // 確保されるメモリを抑えるための指定（#7）。転送量そのものは
        // URL 側の height 指定（AnimalSource 側）で減らしているので、
        // これは「取得したバイト列をどのサイズでデコードするか」という
        // 別軸の最適化になる。BoxFit.cover のポートレートペインなので
        // width ではなく height を基準にする（cardImageCacheHeight 参照）。
        //
        // 注意: Flutter Web の HTML レンダラーでは cacheWidth/cacheHeight
        // はほとんど無視され、ブラウザ側が画像のデコードを担う。
        // したがってここでの効果は非 Web プラットフォーム限定。
        Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheHeight: cacheHeight,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: AppSizes.iconImageError,
                    color: colors.error,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.imageLoadError,
                    style: TextStyle(color: colors.error),
                  ),
                ],
              ),
            );
          },
        ),
        // 画像の上部に半透明のグラデーションを追加
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: AppSizes.imageScrimHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.scrim.withValues(alpha: AppOpacity.imageScrim),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 画像の下部に半透明のグラデーションを追加
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: AppSizes.imageScrimHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  colors.scrim.withValues(alpha: AppOpacity.imageScrim),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
