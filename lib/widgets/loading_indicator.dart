import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final Color color;

  const LoadingIndicator({
    super.key,
    this.color = const Color(0xFFA997E7),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: color),
    );
  }
}
