import 'package:flutter/material.dart';

class PdfItemCard extends StatelessWidget {
  final String title;
  final String path;
  final VoidCallback onOpen;

  const PdfItemCard({
    super.key,
    required this.title,
    required this.path,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, size: 32),
        title: Text(title),
        subtitle: Text(
          path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onOpen,
      ),
    );
  }
}
