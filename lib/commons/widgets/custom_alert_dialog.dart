import 'package:flutter/material.dart';
import 'package:flutterquiz/core/core.dart';

Future<void> showAlertDialog(
  BuildContext context, {
  String? title,
  String? message,
  String? confirmButtonText,
  String? cancelButtonText,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool barrierDismissible = true,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: message != null
          ? SingleChildScrollView(
              child: ListBody(
                children: <Widget>[Text(message, textAlign: TextAlign.start)],
              ),
            )
          : null,
      actions: <Widget>[
        if (cancelButtonText != null)
          TextButton(
            onPressed: onCancel ?? dialogContext.shouldPop,
            child: Text(
              cancelButtonText,
              style: TextStyle(
                color: context.primaryTextColor.withValues(alpha: .8),
                fontSize: 16,
                fontWeight: FontWeights.medium,
              ),
            ),
          ),
        if (confirmButtonText != null)
          TextButton(
            onPressed: () {
              dialogContext.shouldPop();
              onConfirm?.call();
            },
            child: Text(
              confirmButtonText,
              style: TextStyle(
                color: context.primaryColor,
                fontSize: 16,
                fontWeight: FontWeights.medium,
              ),
            ),
          ),
      ],
    ),
  );
}
