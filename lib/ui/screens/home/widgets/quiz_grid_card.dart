import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutterquiz/commons/commons.dart';
import 'package:flutterquiz/core/constants/fonts.dart';

class QuizGridCard extends StatelessWidget {
  const QuizGridCard({
    required this.title,
    required this.desc,
    required this.img,
    super.key,
    this.onTap,
    this.iconOnRight = true,
    this.backgroundSvg,
    this.showSubtitle = true,
  });

  final String title;
  final String desc;
  final String img;
  final bool iconOnRight;
  final void Function()? onTap;
  final String? backgroundSvg;
  final bool showSubtitle;

  ///
  static const _borderRadius = 10.0;
  static const _padding = EdgeInsets.all(12);
  static const _iconBorderRadius = 6.0;
  static const _iconMargin = EdgeInsets.all(5);

  static const _modernBorderRadius = 24.0;
  static const _modernElevation = 12.0;
  static const _modernShadowColor = Color(0xff45536d);

  static const _boxShadow = [
    BoxShadow(
      offset: Offset(0, 50),
      blurRadius: 30,
      spreadRadius: 5,
      color: Color(0xff45536d),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (backgroundSvg != null) {
      return LayoutBuilder(
        builder: (_, constraints) {
          var dimension = constraints.maxWidth;
          if (!dimension.isFinite || dimension <= 0) {
            dimension = constraints.maxHeight;
          }
          if (!dimension.isFinite || dimension <= 0) {
            return const SizedBox.shrink();
          }
          final borderRadius = BorderRadius.circular(_modernBorderRadius);
          final theme = Theme.of(context);
          final baseColor = theme.primaryColor;

          return SizedBox(
            width: dimension,
            height: dimension,
            child: Material(
              elevation: _modernElevation,
              shadowColor: _modernShadowColor,
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    color: baseColor,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SvgPicture.asset(
                          backgroundSvg!,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (_, constraints) {
          var size = constraints.maxWidth;
          if (!size.isFinite || size <= 0) {
            size = constraints.maxHeight;
          }
          if (!size.isFinite || size <= 0) {
            return const SizedBox.shrink();
          }
          final iconSize = size * .28;
          final iconColor = Theme.of(context).primaryColor;

          return Stack(
            children: [
              /// Box Shadow
              Positioned(
                top: 0,
                left: size * 0.2,
                right: size * 0.2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: _boxShadow,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(size * .525),
                    ),
                  ),
                  width: size,
                  height: size * .6,
                ),
              ),

              /// Card
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_borderRadius),
                  color: Theme.of(context).colorScheme.surface,
                ),
                padding: _padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /// Title
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontWeight: FontWeights.semiBold,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onTertiary,
                      ),
                    ),

                    /// Description
                    if (showSubtitle && desc.isNotEmpty)
                      Expanded(
                        child: Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeights.regular,
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiary.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    /// Svg Icon
                    Align(
                      alignment: iconOnRight
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            _iconBorderRadius,
                          ),
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                        padding: _iconMargin,
                        width: iconSize,
                        height: iconSize,
                        child: QImage(
                          imageUrl: img,
                          color: iconColor,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
