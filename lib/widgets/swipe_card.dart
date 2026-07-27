import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../models/animal_model.dart';
import '../theme/theme_extensions.dart';

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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ここには以前 Hero が置かれていたが、遷移先に
                          // 対応する Hero が無く何も起きていなかった。
                          // 一方でカードスタック（#6）により同じ画像が
                          // 同時に複数枚描かれ得るため、tag 衝突で
                          // 「multiple heroes that share the same tag」
                          // アサーションを踏むリスクだけが残っていた。
                          // 全画面拡大表示を入れる時に改めて導入する。
                          Image.network(
                            widget.image.url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.primary,
                                  ),
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
                                    colors.scrim.withValues(
                                      alpha: AppOpacity.imageScrim,
                                    ),
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
                                    colors.scrim.withValues(
                                      alpha: AppOpacity.imageScrim,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
