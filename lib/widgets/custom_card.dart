import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const CustomCard({
    super.key,
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFFA997E7)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: onTap,
        ),
      ),
    );
  }
}