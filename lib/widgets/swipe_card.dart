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
  Offset _dragOffset = Offset.zero;
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
              setState(() => _dragOffset = animation.value);
            }
          })
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed) return;
            final callback = _animationComplete;
            _animationComplete = null;
            callback?.call();
            if (mounted) {
              setState(() {
                _dragOffset = Offset.zero;
                _isDragging = false;
              });
            }
          });
  }

  @override
  void dispose() {
    _controller.dispose();
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
    setState(() => _dragOffset = Offset(rawOffset.dx, rawOffset.dy * 0.18));
  }

  // パンジェスチャー終了時の処理
  void _onPanEnd(DragEndDetails details) {
    if (_isTap) {
      setState(() {
        _isDragging = false;
        _dragOffset = Offset.zero;
      });
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

    if (_dragOffset.dx.abs() > threshold || isFastHorizontalFlick) {
      // 横方向のスワイプが閾値を超えた場合
      final swipedRight = _dragOffset.dx == 0
          ? horizontalVelocity > 0
          : _dragOffset.dx > 0;
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
    final startOffset = _dragOffset;
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
    final startOffset = _dragOffset;
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
    // 回転角度 = _dragOffset.dx / 800
    final rotationAngle = _dragOffset.dx / 900;
    final isLiked = _dragOffset.dx > 0;
    final scale = _isDragging ? 0.975 : 1.0;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: rotationAngle,
          child: Transform.scale(
            scale: scale,
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
                              Hero(
                                tag:
                                    '${AppStrings.animalImageHeroTagPrefix}'
                                    '${widget.image.id}',
                                child: Image.network(
                                  widget.image.url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  colors.primary,
                                                ),
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: AppSizes.iconImageError,
                                            color: colors.error,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            AppStrings.imageLoadError,
                                            style: TextStyle(
                                              color: colors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
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
                if (_dragOffset.dx.abs() > AppSizes.swipeBadgeRevealDistance)
                  Positioned(
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
