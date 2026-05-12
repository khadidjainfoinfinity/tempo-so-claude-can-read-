import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final String? error;
  final TextInputType keyboardType;
  final double? width;


  const CustomTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.error,
    this.keyboardType = TextInputType.text,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: label,
            filled: true,
            fillColor: const Color(0x33C6B3FF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error != null ? Colors.red : Colors.transparent,
                  width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error != null ? Colors.red : const Color(0xFFA997E7),
                  width: 2),
            ),
            errorText: error,
          ),
        ),
      ],
    );
  }
}