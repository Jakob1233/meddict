import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MaterialCategoryOption {
  const MaterialCategoryOption({
    required this.label,
    required this.value,
    required this.assetPath,
  });

  final String label;
  final String value;
  final String assetPath;
}

class MaterialCategoryGrid extends StatelessWidget {
  const MaterialCategoryGrid({
    super.key,
    required this.categories,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<MaterialCategoryOption> categories;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _resolveCrossAxisCount(constraints.maxWidth);
        final theme = Theme.of(context);
        final cardColor = theme.colorScheme.primary;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = category.value == selectedValue;
            return _CategoryTile(
              option: category,
              backgroundColor: cardColor,
              isSelected: isSelected,
              onTap: () => onSelected(category.value),
            );
          },
        );
      },
    );
  }

  int _resolveCrossAxisCount(double maxWidth) {
    if (maxWidth >= 960) return 4;
    if (maxWidth >= 600) return 3;
    return 2;
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.option,
    required this.backgroundColor,
    required this.isSelected,
    required this.onTap,
  });

  final MaterialCategoryOption option;
  final Color backgroundColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = isSelected
        ? backgroundColor
        : Color.alphaBlend(Colors.white.withOpacity(0.08), backgroundColor);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: isSelected ? 6 : 3,
      clipBehavior: Clip.antiAlias,
      color: effectiveColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: SvgPicture.asset(
                    option.assetPath,
                    width: 56,
                    height: 56,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
