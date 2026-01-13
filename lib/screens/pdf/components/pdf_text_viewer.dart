import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../../../theme/colors.dart';

class PdfTextViewer extends StatefulWidget {
  final String pdfPath;
  const PdfTextViewer({super.key, required this.pdfPath});

  @override
  State<PdfTextViewer> createState() => _PdfTextViewerState();
}

class _PdfTextViewerState extends State<PdfTextViewer> {
  String extractedText = "";
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _extractText();
  }

  Future<void> _extractText() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final doc = await PdfDocument.openFile(widget.pdfPath);
      String buffer = "";

      for (int i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        // Essayez d'extraire le texte avec pdfx
        final text = await _tryExtractTextFromPage(page);
        buffer += "Page $i:\n$text\n\n";
        await page.close();
      }

      setState(() {
        extractedText = buffer.trim().isNotEmpty 
            ? buffer 
            : "Aucun texte extractible trouvé. Le PDF peut contenir des images scannées.";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = "Erreur lors de l'extraction: $e";
        isLoading = false;
        extractedText = "Impossible d'extraire le texte. Le PDF peut contenir des images scannées ou être protégé.";
      });
    }
  }

  Future<String> _tryExtractTextFromPage(PdfPage page) async {
    try {
      // Avec pdfx, on peut essayer d'accéder au texte si disponible
      // Note: pdfx a des limitations pour l'extraction de texte
      return "Texte non disponible avec cette version. Utilisez le mode visualisation PDF pour voir le document.";
    } catch (e) {
      return "Erreur d'extraction: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Note: $error",
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      extractedText,
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 15,
                        height: 1.6,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Image.asset(
              "assets/illustrations/pdf_reader.png",
              height: 260,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}