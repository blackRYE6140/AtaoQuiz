// lib/screens/pdf/pdf_reader_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../../theme/colors.dart';
import 'components/pdf_text_viewer.dart';

class PdfReaderScreen extends StatefulWidget {
  final String? pdfPath;

  const PdfReaderScreen({super.key, this.pdfPath});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  PdfControllerPinch? pdfController;
  bool isTextMode = true;
  bool isLoading = true;
  int pagesCount = 0;
  String? loadError;

  @override
  void initState() {
    super.initState();
    if (widget.pdfPath != null) {
      _loadPdf(widget.pdfPath!);
    } else {
      isLoading = false;
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final bytes = await File(path).readAsBytes();

      // Future du document (ce que veut PdfControllerPinch)
      final futureDoc = PdfDocument.openData(bytes);

      // On attend une fois pour récupérer les infos
      final PdfDocument realDoc = await futureDoc;
      pagesCount = realDoc.pagesCount;

      // On passe le Future, pas le document réel
      pdfController = PdfControllerPinch(document: futureDoc);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        loadError = e.toString();
      });
    }
 }


  @override
  void dispose() {
    // Dispose le controller — il nettoie ses ressources internes.
    pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          widget.pdfPath != null ? "Lecture du document" : "Lecture (aucun document)",
          style: TextStyle(
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.pdfPath != null)
            IconButton(
              icon: Icon(
                isTextMode ? Icons.picture_as_pdf : Icons.text_snippet,
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              ),
              onPressed: () => setState(() => isTextMode = !isTextMode),
            ),
        ],
      ),
      body: Builder(builder: (context) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (loadError != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Impossible d'ouvrir le document.\nErreur: $loadError",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
          );
        }

        if (widget.pdfPath == null) {
          return _buildNoPdfView(isDark);
        }

        if (isTextMode) {
          return PdfTextViewer(pdfPath: widget.pdfPath!);
        }

        if (pdfController != null) {
          // PdfViewPinch gère pinch & double-tap automatiquement
          return PdfViewPinch(
            controller: pdfController!,
            onPageChanged: (page) {
              // optionnel : mettre à jour un état si besoin
            },
          );
        } else {
          return Center(
            child: Text(
              "Erreur lors de la préparation du lecteur PDF.",
              style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
            ),
          );
        }
      }),
    );
  }

  Widget _buildNoPdfView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/illustrations/pdf_reader.png", height: 160),
            const SizedBox(height: 20),
            Text(
              "Aucun document ouvert",
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Sélectionnez un PDF pour commencer la lecture.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 14,
                color: isDark ? AppColors.darkText.withOpacity(0.8) : AppColors.lightText.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
