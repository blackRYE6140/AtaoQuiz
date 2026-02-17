// lib/screens/pdf/pdf_list_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'components/pdf_item_card.dart';
import 'pdf_reader_screen.dart';

class PdfListScreen extends StatefulWidget {
  const PdfListScreen({super.key});

  @override
  State<PdfListScreen> createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  final List<Map<String, String>> pdfList = [];

  Future<void> importPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final path = file.path;
      if (path != null) {
        setState(() {
          pdfList.add({'name': file.name, 'path': path});
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'obtenir le chemin du fichier"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = pdfList.isEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.accentYellow
        : AppColors.primaryBlue;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          "Documents PDF",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
      ),
      body: isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 64,
                      color: primaryColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Aucun document",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Importez un PDF pour commencer",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: pdfList.length,
              itemBuilder: (context, index) {
                final item = pdfList[index];
                return PdfItemCard(
                  title: item['name'] ?? 'Document',
                  path: item['path'] ?? '',
                  onOpen: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfReaderScreen(pdfPath: item['path']),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: importPdf,
        backgroundColor: primaryColor,
        foregroundColor: isDark ? Colors.black : Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text("Importer PDF"),
      ),
    );
  }
}
