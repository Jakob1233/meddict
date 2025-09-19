import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';

/// Shared dropdown wrapper that aligns every dropdown on top of
/// animated_custom_dropdown while keeping the existing forms API small.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    this.label,
    this.hintText,
    required this.items,
    required this.itemLabel,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.searchable = true,
    this.borderRadius = 16,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
  });

  final String? label;
  final String? hintText;
  final List<T> items;
  final T? value;
  final void Function(T?)? onChanged;
  final String Function(T) itemLabel;
  final String? Function(T?)? validator;
  final bool enabled;
  final bool searchable;
  final double borderRadius;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const textColor = Colors.white;
    final baseFill = isDark
        ? const Color(0xFF121212)
        : const Color(0xFF1B1B1B).withOpacity(0.9);
    final borderColor = Colors.white24;

    final decoration = CustomDropdownDecoration(
      closedFillColor: baseFill,
      expandedFillColor: baseFill,
      closedBorder: Border.all(color: borderColor, width: 1),
      expandedBorder: Border.all(color: borderColor, width: 1),
      closedBorderRadius: BorderRadius.circular(borderRadius),
      expandedBorderRadius: BorderRadius.circular(borderRadius),
      closedSuffixIcon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: textColor,
      ),
      expandedSuffixIcon: const Icon(
        Icons.keyboard_arrow_up_rounded,
        color: textColor,
      ),
      hintStyle: TextStyle(
        color: textColor.withOpacity(0.7),
        fontWeight: FontWeight.w500,
      ),
      headerStyle: const TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      listItemStyle: const TextStyle(
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
    );

    final disabledDecoration = CustomDropdownDisabledDecoration(
      fillColor: baseFill.withOpacity(0.5),
      border: Border.all(color: borderColor.withOpacity(0.4), width: 1),
      borderRadius: BorderRadius.circular(borderRadius),
      suffixIcon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: textColor.withOpacity(0.5),
      ),
      headerStyle: TextStyle(
        color: textColor.withOpacity(0.5),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: textColor.withOpacity(0.4),
        fontWeight: FontWeight.w500,
      ),
    );

    Widget header() {
      if (label == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label!,
          style:
              theme.textTheme.labelMedium?.copyWith(color: textColor) ??
              const TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      );
    }

    Widget listItemBuilder(
      BuildContext context,
      T item,
      bool isSelected,
      VoidCallback onItemSelect,
    ) {
      return Text(
        itemLabel(item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: textColor, fontWeight: FontWeight.w500),
      );
    }

    Widget headerBuilder(BuildContext context, T item, bool isEnabled) {
      return Text(
        itemLabel(item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor.withOpacity(isEnabled ? 1 : 0.5),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    Widget buildDropdown() {
      final listItemPadding = const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      );
      final padding = contentPadding;

      if (searchable) {
        return CustomDropdown<T>.search(
          items: items,
          initialItem: value,
          hintText: hintText,
          searchHintText: 'Suchen…',
          validator: validator,
          onChanged: (selected) => onChanged?.call(selected),
          decoration: decoration,
          disabledDecoration: disabledDecoration,
          enabled: enabled,
          closedHeaderPadding: padding,
          expandedHeaderPadding: padding,
          itemsListPadding: EdgeInsets.zero,
          listItemPadding: listItemPadding,
          listItemBuilder: listItemBuilder,
          headerBuilder: headerBuilder,
          excludeSelected: false,
        );
      }

      return CustomDropdown<T>(
        items: items,
        initialItem: value,
        hintText: hintText,
        validator: validator,
        onChanged: (selected) => onChanged?.call(selected),
        decoration: decoration,
        disabledDecoration: disabledDecoration,
        enabled: enabled,
        closedHeaderPadding: padding,
        expandedHeaderPadding: padding,
        itemsListPadding: EdgeInsets.zero,
        listItemPadding: listItemPadding,
        listItemBuilder: listItemBuilder,
        headerBuilder: headerBuilder,
        excludeSelected: false,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) header(),
        buildDropdown(),
      ],
    );
  }
}
