import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CircularProgressContainer extends StatelessWidget {
  const CircularProgressContainer({
    super.key,
    this.whiteLoader = false,
    this.size = 40,
  });

  final bool whiteLoader;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/loader/Catloader.json',
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to a JSON loader if .lottie fails to parse/load
          return Lottie.asset(
            'assets/loader/Cosmos.json',
            fit: BoxFit.contain,
            repeat: true,
          );
        },
      ),
    );
  }
}
