import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_strings.dart';
import '../providers/animal_providers.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/gradient_background.dart';
import 'swipe_screen.dart';

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  static const _animalTypes = [
    (
      id: 'cat',
      name: AppStrings.animalCat,
      description: AppStrings.animalCatDescription,
      emoji: AppStrings.animalCatEmoji,
    ),
    (
      id: 'dog',
      name: AppStrings.animalDog,
      description: AppStrings.animalDogDescription,
      emoji: AppStrings.animalDogEmoji,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTypes = ref.watch(selectedAnimalTypesProvider);
    // GradientBackground は primary をベースにするため、その上の前景は onPrimary 系
    final onGradientMuted = context.colors.onPrimary.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 420
                  ? 20.0
                  : 32.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  28,
                  horizontalPadding,
                  24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 52,
                    maxWidth: 560,
                  ),
                  child: Column(
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 36),
                      _SelectionPanel(
                        selectedTypes: selectedTypes,
                        onToggle: (type, isSelected) {
                          ref
                              .read(selectedAnimalTypesProvider.notifier)
                              .selectType(type, isSelected);
                        },
                        onStart: selectedTypes.isEmpty
                            ? null
                            : () {
                                ref
                                    .read(selectedAnimalTypesProvider.notifier)
                                    .saveSelectedTypes();
                                // 新しいセッションの開始として山札を必ず取り直す。
                                // pushReplacement の遷移中は旧 SwipeScreen と
                                // 新 SwipeScreen が重なり購読者が 0 にならないため、
                                // autoDispose だけに頼ると山札が尽きたまま
                                // 再開されてしまう
                                ref.invalidate(animalImagesProvider);
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SwipeScreen(),
                                  ),
                                );
                              },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.swipe_rounded,
                              size: 18,
                              color: onGradientMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.swipeHint,
                              style: TextStyle(
                                color: onGradientMuted,
                                fontFamily: AppStrings.fontFamily,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    // GradientBackground（primary ベース）の上に乗るので前景は onPrimary
    final onGradient = context.colors.onPrimary;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: onGradient.withValues(alpha: 0.24),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(Icons.pets_rounded, color: onGradient, size: 30),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppStrings.appName,
          textAlign: TextAlign.center,
          style: TextStyle(
            height: 1,
            fontSize: 42,
            fontFamily: AppStrings.fontFamily,
            fontWeight: FontWeight.bold,
            letterSpacing: -1.5,
            color: onGradient,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: onGradient,
            fontFamily: AppStrings.fontFamily,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _SelectionPanel extends StatelessWidget {
  final List<String> selectedTypes;
  final void Function(String type, bool isSelected) onToggle;
  final VoidCallback? onStart;

  const _SelectionPanel({
    required this.selectedTypes,
    required this.onToggle,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              AppStrings.selectAnimalPrompt,
              style: TextStyle(
                fontFamily: AppStrings.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.selectAnimalHint,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
              ),
              itemCount: StartScreen._animalTypes.length,
              itemBuilder: (context, index) {
                final type = StartScreen._animalTypes[index];
                final isSelected = selectedTypes.contains(type.id);
                return _AnimalChoice(
                  name: type.name,
                  description: type.description,
                  emoji: type.emoji,
                  isSelected: isSelected,
                  onTap: () => onToggle(type.id, !isSelected),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor:
                      context.colors.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.startButton,
                      style: TextStyle(
                        fontFamily: AppStrings.fontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalChoice extends StatelessWidget {
  final String name;
  final String description;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimalChoice({
    required this.name,
    required this.description,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$nameを選択',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.primaryContainer
                  : context.colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? context.colors.primary
                    : context.colors.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 44)),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: AppStrings.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppStrings.fontFamily,
                          fontSize: 10,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.check,
                      color: context.colors.primary,
                      size: 24,
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
