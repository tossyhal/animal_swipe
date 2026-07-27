import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../models/animal_model.dart';
import '../providers/favorites_provider.dart';
import '../services/animal_source.dart';
import '../theme/theme_extensions.dart';
import '../widgets/swipe_card.dart';

/// グリッドのサムネイルをデコードする解像度（デバイス px）を計算する
///
/// タイルは画面幅の約 1/[AppSizes.favoritesGridColumns] しか占めないのに、
/// 何もしないと [Image.network] は取得した画像を原寸でデコードする。
/// 上限 200 件をスクロールすると数メガピクセルのデコードが積み上がり、
/// `ImageCache` を食い潰してメモリ圧迫やジャンクの原因になる。
///
/// スワイプ画面と同じく [kCardImageCacheHeightBucket] 単位に切り上げて
/// バケツ化し、ウィンドウリサイズのたびにキーがずれて再デコードが
/// 走るのを防ぐ。取得画像自体の解像度（[kCatImageHeight]）でクランプ
/// するのも同じ理由で、届いていない解像度を要求しても意味がない。
int? favoritesThumbnailCacheWidth(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final tileWidth = mediaQuery.size.width / AppSizes.favoritesGridColumns;
  final rawWidth = tileWidth * mediaQuery.devicePixelRatio;
  if (rawWidth <= 0) return null;
  final bucketed =
      (rawWidth / kCardImageCacheHeightBucket).ceil() *
      kCardImageCacheHeightBucket;
  return math.min(bucketed, kCatImageHeight);
}

/// お気に入り一覧画面
///
/// グリッドでお気に入りを並べ、タップで簡易的な拡大表示、長押しで削除できる。
///
/// ## 拡大表示について（#8 / #26 との関係）
///
/// ここでの拡大表示は [showDialog] を使った自前の簡易実装に留めている。
/// 全画面の画像ビューア（ピンチズーム等）は #26 で別に実装が進んでおり、
/// `lib/widgets/full_screen_image_viewer.dart` のような共通ウィジェットが
/// できる可能性がある。同じ役割のウィジェットを競合して作らないよう、
/// この画面はまず動く最小限の実装にとどめ、#26 が完成した後に
/// そちらへ差し替える余地を残す。
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.favoritesTitle)),
      body: favorites.isEmpty
          ? const _EmptyFavorites()
          : GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.s16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppSizes.favoritesGridColumns,
                crossAxisSpacing: AppSizes.favoritesGridSpacing,
                mainAxisSpacing: AppSizes.favoritesGridSpacing,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final image = favorites[index];
                return _FavoriteTile(
                  image: image,
                  onTap: () => _showEnlarged(context, image),
                  onLongPress: () => _confirmDelete(context, ref, image),
                );
              },
            ),
    );
  }

  Future<void> _showEnlarged(BuildContext context, AnimalImage image) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Image.network(
                image.url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.s32),
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: AppSizes.iconImageError,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.favoritesDialogClose),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AnimalImage image,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.favoritesDeleteDialogTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.favoritesDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.favoritesDeleteDialogConfirm),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      ref.read(favoritesProvider.notifier).remove(image);
    }
  }
}

class _FavoriteTile extends StatelessWidget {
  final AnimalImage image;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FavoriteTile({
    required this.image,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.favoriteTile),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Image.network(
          image.url,
          fit: BoxFit.cover,
          // タイルは画面幅の 1/3 程度しか占めない。原寸デコードを避ける
          // （拡大ダイアログ側は原寸のまま扱う）
          cacheWidth: favoritesThumbnailCacheWidth(context),
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: context.colors.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_outlined,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: AppSizes.iconFavoritesEmpty,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              AppStrings.favoritesEmptyTitle,
              textAlign: TextAlign.center,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              AppStrings.favoritesEmptyMessage,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
