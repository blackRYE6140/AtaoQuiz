// lib/screens/pdf/pdf_list_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
      // file.path peut être null sur le web ; ici on suppose mobile
      final path = file.path;
      if (path != null) {
        setState(() {
          pdfList.add({'name': file.name, 'path': path});
        });
      } else {
        // Cas improbable sur mobile, message à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'obtenir le chemin du fichier")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = pdfList.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Documents PDF"),
        centerTitle: true,
      ),
      body: isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("Aucun document", style: TextStyle(fontSize: 16)),
                ],
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
        icon: const Icon(Icons.upload_file),
        label: const Text("Importer PDF"),
      ),
    );
  }
}
