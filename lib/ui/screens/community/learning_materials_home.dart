import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'learning_materials_list.dart';
import 'learning_materials_types.dart';

class LearningMaterialsHomeScreen extends StatelessWidget {
  const LearningMaterialsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = LearningMaterialTypeData.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lernmaterialien'),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            final type = tiles[index];
            return _MaterialHomeTile(
              typeData: type,
              onTap: () => _openList(context, type),
              primaryColor: theme.colorScheme.primary,
              labelStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              backgroundColor: theme.cardColor,
            );
          },
        ),
      ),
    );
  }

  void _openList(BuildContext context, LearningMaterialTypeData type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningMaterialsListScreen(type: type),
      ),
    );
  }
}

class _MaterialHomeTile extends StatelessWidget {
  const _MaterialHomeTile({
    required this.typeData,
    required this.onTap,
    required this.primaryColor,
    required this.labelStyle,
    required this.backgroundColor,
  });

  final LearningMaterialTypeData typeData;
  final VoidCallback onTap;
  final Color primaryColor;
  final TextStyle? labelStyle;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: SvgPicture.asset(
                    typeData.assetPath,
                    width: 64,
                    height: 64,
                    fit: BoxFit.none,
                    colorFilter: ColorFilter.mode(
                      primaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                typeData.label,
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
