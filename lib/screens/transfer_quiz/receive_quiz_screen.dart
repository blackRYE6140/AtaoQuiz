import 'package:atao_quiz/screens/transfer_quiz/qr_scanner_screen.dart';
import 'package:atao_quiz/services/quiz_transfer_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiveQuizScreen extends StatefulWidget {
  const ReceiveQuizScreen({super.key});

  @override
  State<ReceiveQuizScreen> createState() => _ReceiveQuizScreenState();
}

class _ReceiveQuizScreenState extends State<ReceiveQuizScreen> {
  final QuizTransferService _transferService = QuizTransferService();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '${QuizTransferService.defaultPort}',
  );

  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _transferService.addListener(_onTransferStateChanged);
    _transferService.initialize();
  }

  @override
  void dispose() {
    _transferService.removeListener(_onTransferStateChanged);
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onTransferStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  int? _validatedPort() {
    final parsed = int.tryParse(_portController.text.trim());
    if (parsed == null || parsed < 1 || parsed > 65535) {
      return null;
    }
    return parsed;
  }

  Future<void> _startHosting() async {
    final port = _validatedPort();
    if (port == null) {
      _showMessage('Port invalide.', isError: true);
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _transferService.startHosting(port: port);
      if (!mounted) {
        return;
      }
      _showMessage('Serveur lancé sur le port $port.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('Impossible de démarrer le serveur: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _stopHosting() async {
    setState(() => _isBusy = true);
    try {
      await _transferService.stopHosting(keepConnection: false);
      if (!mounted) {
        return;
      }
      _showMessage('Serveur arrêté.');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _connectManually() async {
    final host = _hostController.text.trim();
    final port = _validatedPort();
    if (host.isEmpty) {
      _showMessage('Entrez une adresse IP.', isError: true);
      return;
    }
    if (port == null) {
      _showMessage('Port invalide.', isError: true);
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _transferService.connectToPeer(host: host, port: port);
      if (!mounted) {
        return;
      }
      _showMessage('Connecté à $host:$port');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('Connexion impossible: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _scanQrAndConnect() async {
    final payload = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    final target = _transferService.parseTransferPayload(payload);
    if (target == null) {
      _showMessage('QR code invalide.', isError: true);
      return;
    }

    _hostController.text = target.host;
    _portController.text = '${target.port}';
    await _connectManually();
  }

  Future<void> _reconnect() async {
    setState(() => _isBusy = true);
    try {
      await _transferService.reconnectLastPeer();
      if (!mounted) {
        return;
      }
      _showMessage('Reconnexion réussie.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('Reconnexion impossible: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isBusy = true);
    await _transferService.disconnect();
    if (mounted) {
      setState(() => _isBusy = false);
    }
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

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
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
    final qrPayload = _transferService.buildQrPayload();

    final canAct = !_isBusy && !_transferService.isSendingBatch;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'État de session',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _transferService.isConnected
                        ? Icons.check_circle
                        : _transferService.isHosting
                        ? Icons.wifi_tethering
                        : Icons.portable_wifi_off,
                    color: _transferService.isConnected
                        ? AppColors.success
                        : primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _transferService.statusMessage,
                      style: TextStyle(color: textColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Une fois connectés, les deux téléphones peuvent envoyer et recevoir.',
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
              if (_transferService.connectedPeer != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Pair: ${_transferService.connectedPeer}',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Port et adresse',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _transferService.localIps.isEmpty
                    ? 'IP locale indisponible.'
                    : 'IP locale: ${_transferService.localIps.join(' , ')}',
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode hôte (point de connexion)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canAct ? _startHosting : null,
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Lancer serveur'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canAct ? _stopHosting : null,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Arrêter'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (qrPayload == null)
                Text(
                  'QR indisponible: connectez-vous au réseau Wi-Fi puis relancez.',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                )
              else
                Center(
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Le second téléphone peut scanner ce QR.',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode client (se connecter)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'IP hôte',
                  hintText: 'Ex: 192.168.1.10',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canAct ? _scanQrAndConnect : null,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scanner QR'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canAct ? _connectManually : null,
                      icon: const Icon(Icons.link),
                      label: const Text('Connecter'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canAct && _transferService.canReconnect
                          ? _reconnect
                          : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reconnecter'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canAct && _transferService.isConnected
                          ? _disconnect
                          : null,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Déconnecter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
