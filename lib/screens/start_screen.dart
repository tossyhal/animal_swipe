import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import '../providers/animal_providers.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/gradient_background.dart';
import 'swipe_screen.dart';

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 選択中の動物タイプを監視
    final selectedTypes = ref.watch(selectedAnimalTypesProvider);

    // 利用可能な動物タイプ一覧
    final List<Map<String, dynamic>> availableTypes = [
      {
        'id': 'cat',
        'name': AppStrings.animalCat,
        'icon': Icons.pets,
        'emoji': AppStrings.animalCatEmoji,
      },
      {
        'id': 'dog',
        'name': AppStrings.animalDog,
        'icon': Icons.pets,
        'emoji': AppStrings.animalDogEmoji,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 使用可能な高さを取得
              final availableHeight = constraints.maxHeight;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: availableHeight),
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(height: AppConstants.paddingLarge),
                        // アプリタイトル
                        const Text(
                          AppStrings.appName,
                          style: TextStyle(
                            fontSize: AppConstants.fontSizeTitle,
                            fontFamily: AppStrings.fontFamily,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 5.0,
                                color: Colors.black26,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height:
                              availableHeight *
                                  AppConstants.layoutSpacingPercentage,
                        ),
                        // 動物選択部分
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.paddingLarge,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(
                              AppConstants.paddingMedium,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: AppConstants.opacityHigh,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppConstants.borderRadiusLarge,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: AppConstants.opacityMinimal,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    AppStrings.selectAnimalPrompt,
                                    style: TextStyle(
                                      fontSize: AppConstants.fontSizeLarge,
                                      fontFamily: AppStrings.fontFamily,
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppConstants.paddingLarge),
                                // グリッドで動物タイプを表示
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            AppConstants.gridCrossAxisCount,
                                        childAspectRatio:
                                            AppConstants.gridChildAspectRatio,
                                        crossAxisSpacing:
                                            AppConstants.gridCrossAxisSpacing,
                                        mainAxisSpacing:
                                            AppConstants.gridMainAxisSpacing,
                                      ),
                                  itemCount: availableTypes.length,
                                  itemBuilder: (context, index) {
                                    final type = availableTypes[index];
                                    final bool isSelected = selectedTypes
                                        .contains(type['id']);

                                    return InkWell(
                                      onTap: () {
                                        // 選択状態の切り替え
                                        ref
                                            .read(
                                              selectedAnimalTypesProvider
                                                  .notifier,
                                            )
                                            .selectType(
                                              type['id'] as String,
                                              !isSelected,
                                            );
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds:
                                              AppConstants.animationDurationShort,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? context.colors.primaryContainer
                                                  : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            AppConstants.borderRadiusMedium,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  isSelected
                                                      ? context.colors.primary
                                                          .withValues(
                                                            alpha:
                                                                AppConstants
                                                                    .opacityLow,
                                                          )
                                                      : Colors.grey.withValues(
                                                        alpha:
                                                            AppConstants
                                                                .opacityExtraLow,
                                                      ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  type['emoji'] as String,
                                                  style: const TextStyle(
                                                    fontSize:
                                                        AppConstants.fontSizeEmoji,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: AppConstants.paddingSmall,
                                                ),
                                                Text(
                                                  type['name'] as String,
                                                  style: TextStyle(
                                                    fontSize:
                                                        AppConstants.fontSizeXLarge,
                                                    fontFamily:
                                                        AppStrings.fontFamily,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        isSelected
                                                            ? context.colors
                                                                .onPrimaryContainer
                                                            : Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (isSelected)
                                              Positioned(
                                                top: AppConstants.paddingSmall,
                                                right: AppConstants.paddingSmall,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    AppConstants.paddingXSmall,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: context.colors.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size:
                                                        AppConstants.iconSizeSmall,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: AppConstants.paddingLarge),
                                // 「始める」ボタン（選択がない場合は無効）
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        selectedTypes.isEmpty
                                            ? null
                                            : () {
                                              // 選択状態の保存
                                              ref
                                                  .read(
                                                    selectedAnimalTypesProvider
                                                        .notifier,
                                                  )
                                                  .saveSelectedTypes();
                                              // 画面遷移：SwipeScreenへ
                                              Navigator.of(
                                                context,
                                              ).pushReplacement(
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                          const SwipeScreen(),
                                                ),
                                              );
                                            },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppConstants.paddingMedium,
                                      ),
                                      backgroundColor: context.colors.primary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Colors.grey.shade300,
                                      elevation: AppConstants.elevationLow,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppConstants.borderRadiusMedium,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      AppStrings.startButton,
                                      style: TextStyle(
                                        fontSize: AppConstants.fontSizeLarge,
                                        fontFamily: AppStrings.fontFamily,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            selectedTypes.isEmpty
                                                ? Colors.grey.shade500
                                                : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          height:
                              availableHeight *
                                  AppConstants.layoutSpacingPercentage,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
