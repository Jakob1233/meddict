import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String _iconForExamTitle(String title, {bool isDent = false}) {
  final t = title.toLowerCase();
  if (t.contains('herz') || t.contains('kardio')) {
    return 'assets/icons/exams/heart.svg';
  }
  if (t.contains('pulmo') || t.contains('lunge') || t.contains('atmung')) {
    return 'assets/icons/exams/lungs.svg';
  }
  if (t.contains('neuro') || t.contains('nerv')) {
    return 'assets/icons/exams/brain.svg';
  }
  if (t.contains('psyche') || t.contains('psychi')) {
    return 'assets/icons/exams/brain.svg';
  }
  if (t.contains('niere') || t.contains('uro') || t.contains('harn')) {
    return 'assets/icons/exams/kidney.svg';
  }
  if (t.contains('gastro') ||
      t.contains('hepato') ||
      t.contains('leber') ||
      t.contains('darm') ||
      t.contains('verdau') ||
      t.contains('stoffwechsel')) {
    return 'assets/icons/exams/stomach.svg';
  }
  if (t.contains('mikro') || t.contains('infekt') || t.contains('bakter') || t.contains('virolog')) {
    return 'assets/icons/exams/bacteria.svg';
  }
  if (t.contains('pharma') || t.contains('toxik') || t.contains('medikament')) {
    return 'assets/icons/exams/capsules.svg';
  }
  if (t.contains('genetik') || t.contains('genom') || t.contains('bio') || t.contains('molek')) {
    return 'assets/icons/exams/dna.svg';
  }
  if (isDent ||
      t.contains('zahn') ||
      t.contains('dent') ||
      t.contains('kfo') ||
      t.contains('prothetik') ||
      t.contains('endo') ||
      t.contains('paro')) {
    return 'assets/icons/exams/tooth.svg';
  }
  return 'assets/icons/exams/book.svg';
}

Widget buildExamIcon(BuildContext context, String title, {bool isDent = false}) {
  final theme = Theme.of(context);
  final iconPath = _iconForExamTitle(title, isDent: isDent);
  final backgroundColor = theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceVariant.withOpacity(0.35)
      : theme.colorScheme.surface;

  return Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: kElevationToShadow[1],
    ),
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.all(10),
    child: SvgPicture.asset(
      iconPath,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(theme.colorScheme.primary, BlendMode.srcIn),
    ),
  );
}
