import 'package:atao_quiz/services/quiz_transfer_service.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class SendQuizScreen extends StatefulWidget {
  const SendQuizScreen({super.key});

  @override
  State<SendQuizScreen> createState() => _SendQuizScreenState();
}

class _SendQuizScreenState extends State<SendQuizScreen> {
  final StorageService _storageService = StorageService();
  final QuizTransferService _transferService = QuizTransferService();

  List<Quiz> _quizzes = [];
  Set<String> _selectedQuizIds = <String>{};
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _transferService.addListener(_onTransferStateChanged);
    _transferService.initialize();
    _loadQuizzes();
  }

  @override
  void dispose() {
    _transferService.removeListener(_onTransferStateChanged);
    super.dispose();
  }

  void _onTransferStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);
    final quizzes = await _storageService.getQuizzes();
    quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _quizzes = quizzes;
      _selectedQuizIds = _selectedQuizIds
          .where((id) => _quizzes.any((quiz) => quiz.id == id))
          .toSet();
      _isLoading = false;
    });
  }

  Future<void> _sendSelectedQuizzes() async {
    if (!_transferService.isConnected) {
      _showMessage('Connectez-vous à un pair avant l\'envoi.', isError: true);
      return;
    }

    final selected = _quizzes
        .where((quiz) => _selectedQuizIds.contains(quiz.id))
        .toList();
    if (selected.isEmpty) {
      _showMessage('Aucun quiz sélectionné.', isError: true);
      return;
    }

    setState(() => _isSending = true);
    try {
      await _transferService.sendQuizzes(selected);
      if (!mounted) {
        return;
      }
      _showMessage('${selected.length} quiz envoyés.');
      setState(() => _selectedQuizIds.clear());
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('Erreur d\'envoi: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _toggleQuizSelection(String quizId, bool selected) {
    setState(() {
      if (selected) {
        _selectedQuizIds.add(quizId);
      } else {
        _selectedQuizIds.remove(quizId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedQuizIds.length == _quizzes.length) {
        _selectedQuizIds.clear();
      } else {
        _selectedQuizIds = _quizzes.map((quiz) => quiz.id).toSet();
      }
    });
  }

  Future<void> _deleteHistoryEntry(TransferHistoryEntry entry) async {
    final ask = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet élément ?'),
        content: Text(
          entry.receivedQuizId != null
              ? 'Ce quiz reçu sera supprimé de Mes Quiz et retiré de l\'historique.'
              : 'Cet élément sera retiré de l\'historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (ask != true) {
      return;
    }

    await _transferService.removeHistoryEntry(entry);
    await _loadQuizzes();
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  IconData _iconForEntry(TransferHistoryEntry entry) {
    if (entry.direction == TransferDirection.sent) {
      return entry.status == TransferStatus.success
          ? Icons.north_east
          : Icons.error_outline;
    }
    if (entry.direction == TransferDirection.received) {
      return entry.status == TransferStatus.success
          ? Icons.south_west
          : Icons.warning_amber_outlined;
    }
    return Icons.info_outline;
  }

  Color _colorForEntry(TransferHistoryEntry entry, bool isDark) {
    if (entry.status == TransferStatus.success) {
      return AppColors.success;
    }
    if (entry.status == TransferStatus.failed) {
      return AppColors.error;
    }
    return isDark ? AppColors.accentYellow : AppColors.primaryBlue;
  }

  String _formatDate(DateTime dateTime) {
    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final y = dateTime.year.toString();
    final h = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  BoxDecoration _cardDecoration(bool isDark, Color primaryColor) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      border: Border.all(color: primaryColor.withValues(alpha: 0.32)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.accentYellow
        : AppColors.primaryBlue;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final isBusy = _isSending || _transferService.isSendingBatch;
    final connectedLabel = _transferService.isConnected
        ? _transferService.connectedPeersCount == 1
              ? 'Connecté: ${_transferService.connectedPeer ?? 'pair'}'
              : '${_transferService.connectedPeersCount} pairs connectés'
        : 'Aucun pair connecté';

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return RefreshIndicator(
      onRefresh: _loadQuizzes,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(isDark, primaryColor),
            child: Row(
              children: [
                Icon(
                  _transferService.isConnected ? Icons.link : Icons.link_off,
                  color: _transferService.isConnected
                      ? AppColors.success
                      : secondaryTextColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connectedLabel,
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quiz à envoyer (${_quizzes.length})',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ),
              if (_quizzes.isNotEmpty)
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    _selectedQuizIds.length == _quizzes.length
                        ? 'Tout désélectionner'
                        : 'Tout sélectionner',
                  ),
                ),
            ],
          ),
          if (_quizzes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark, primaryColor),
              child: Text(
                'Aucun quiz disponible.',
                style: TextStyle(color: secondaryTextColor),
              ),
            )
          else
            ..._quizzes.map((quiz) {
              final selected = _selectedQuizIds.contains(quiz.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: _cardDecoration(isDark, primaryColor),
                child: CheckboxListTile(
                  value: selected,
                  onChanged: isBusy
                      ? null
                      : (checked) =>
                            _toggleQuizSelection(quiz.id, checked ?? false),
                  title: Text(
                    quiz.title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${quiz.questionCount} questions • ${quiz.difficulty}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  activeColor: primaryColor,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
            }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : _sendSelectedQuizzes,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(
                isBusy
                    ? 'Envoi en cours...'
                    : 'Envoyer ${_selectedQuizIds.length} quiz',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Historique provisoire (${_transferService.history.length})',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ),
              if (_transferService.history.isNotEmpty)
                TextButton.icon(
                  onPressed: _transferService.clearHistory,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Vider'),
                ),
            ],
          ),
          if (_transferService.history.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark, primaryColor),
              child: Text(
                'Aucun transfert pour le moment.',
                style: TextStyle(color: secondaryTextColor),
              ),
            )
          else
            ..._transferService.history.map((entry) {
              final color = _colorForEntry(entry, isDark);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: _cardDecoration(isDark, primaryColor),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(_iconForEntry(entry), color: color),
                  ),
                  title: Text(
                    entry.title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.message}\n${_formatDate(entry.timestamp)}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () => _deleteHistoryEntry(entry),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
