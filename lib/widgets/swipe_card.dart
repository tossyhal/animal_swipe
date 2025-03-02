import 'package:flutter/material.dart';
import '../models/animal_model.dart';

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
  Offset _dragOffset = Offset.zero;
  Offset _dragStartPosition = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
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
      _dragStartPosition = details.globalPosition;
    });
  }

  // パンジェスチャー更新時の処理
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = details.globalPosition - _dragStartPosition;
    });
  }

  // パンジェスチャー終了時の処理
  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 閾値 = screenWidth * 0.4
    const thresholdFraction = 0.4;
    final threshold = screenWidth * thresholdFraction;

    if (_dragOffset.dx.abs() > threshold) {
      // 横方向のスワイプが閾値を超えた場合
      if (_dragOffset.dx > 0) {
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

    _controller.reset();

    Animation<Offset> animation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        onComplete();
        setState(() {
          _dragOffset = Offset.zero;
          _isDragging = false;
        });
      }
    });

    _controller.forward();
  }

  // スワイプ失敗時にカードを中央に戻すアニメーション
  void _animateCardBack() {
    final startOffset = _dragOffset;
    final endOffset = Offset.zero;

    _controller.reset();

    Animation<Offset> animation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isDragging = false;
        });
      }
    });

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    // 回転角度 = _dragOffset.dx / 800
    final rotationAngle = _dragOffset.dx / 800;
    final isLiked = _dragOffset.dx > 0;
    final scale = _isDragging ? 0.95 : 1.0;

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
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // 丸みを増加
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
                                tag: 'animal_image_${widget.image.id}',
                                child: Image.network(
                                  widget.image.url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
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
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
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
                                            size: 48,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '画像の読み込みに失敗しました',
                                            style: TextStyle(
                                              fontFamily: 'MPLUSRounded1c',
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.error,
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
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
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
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
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
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.image.description != null)
                                Text(
                                  widget.image.description!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'MPLUSRounded1c',
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.image.type.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'MPLUSRounded1c',
                                        fontWeight: FontWeight.w500,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
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
                // スワイプ方向に応じたアイコン表示（ドラッグ量が20を超えた場合）
                if (_dragOffset.dx.abs() > 20)
                  Positioned(
                    top: 20,
                    right: isLiked ? 20 : null,
                    left: isLiked ? null : 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isLiked
                                ? Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.9)
                                : Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isLiked
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).colorScheme.error)
                                .withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.close,
                        color: Colors.white,
                        size: 36,
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
