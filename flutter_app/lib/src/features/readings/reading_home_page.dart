import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_texts.dart';
import '../../core/idempotency_key.dart';
import '../../core/language_picker_button.dart';
import '../../core/localization_service.dart';
import '../../core/tarot_functions_client.dart';
import '../auth/auth_service.dart';
import '../purchases/restore_purchase_item.dart';
import 'reading_models.dart';

class ReadingHomePage extends StatefulWidget {
  const ReadingHomePage({
    super.key,
    required this.authService,
    required this.uid,
  });

  final AuthService authService;
  final String uid;

  @override
  State<ReadingHomePage> createState() => _ReadingHomePageState();
}

class _ReadingHomePageState extends State<ReadingHomePage> {
  final _intentController = TextEditingController();
  final _cardsController = TextEditingController(
    text: 'The Fool,The Star,Justice',
  );
  final _client = TarotFunctionsClient();

  bool _loading = false;
  ReadingResult? _lastResult;

  @override
  void dispose() {
    _intentController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _generateReading() async {
    final cards = _cardsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cards.isEmpty) {
      _showError(AppTexts.t('error.cards_required'));
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _client.generateTarotReading(
        ReadingRequest(
          intent: _intentController.text.trim(),
          cards: cards,
          idempotencyKey: createIdempotencyKey(),
        ),
      );
      setState(() => _lastResult = result);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restorePurchases() async {
    try {
      final response = await _client.restoreIosPurchases(
        const <RestorePurchaseItem>[],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '${AppTexts.t('reading.restore_result')}: $response',
          ),
        ),
      );
    } catch (e) {
      _showError('${AppTexts.t('toast.restore_pending')}: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final readingId = _lastResult?.readingId;

    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) => Scaffold(
        appBar: AppBar(
          title: Text(AppTexts.t('reading.title')),
          actions: [
            LanguagePickerButton(
              onSelected: (lang) async {
                await LocalizationService.instance.setLanguage(lang);
                try {
                  await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
                    'settings': {'lang': lang}
                  }, SetOptions(merge: true));
                } catch (_) {}
                if (mounted) setState(() {});
              },
            ),
            TextButton(
              onPressed: _restorePurchases,
              child: Text(AppTexts.t('common.restore')),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => widget.authService.signOut(),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _intentController,
                decoration:
                    InputDecoration(labelText: AppTexts.t('reading.intent')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cardsController,
                decoration: InputDecoration(
                  labelText: AppTexts.t('reading.cards'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _generateReading,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppTexts.t('common.generate')),
              ),
              const SizedBox(height: 20),
              if (_lastResult != null) ...[
                Text(
                  '${AppTexts.t('reading.id')}: ${_lastResult!.readingId}',
                ),
                Text(
                  '${AppTexts.t('reading.remaining_credits')}: ${_lastResult!.remainingCredits}',
                ),
                const SizedBox(height: 12),
              ],
              if (readingId != null)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.uid)
                      .collection('readings')
                      .doc(readingId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Text(AppTexts.t('reading.waiting'));
                    }

                    final data = snapshot.data!.data()!;
                    final aiResponse = (data['aiResponse'] ?? '') as String;
                    final status = (data['status'] ?? '-') as String;
                    final audioStatus = (data['audioStatus'] ?? '-') as String;
                    final audioUrl = data['audioUrl'] as String?;
                    final shareUrl = data['shareImageUrl'] as String?;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${AppTexts.t('reading.status')}: $status'),
                            Text(
                              '${AppTexts.t('reading.audio_status')}: $audioStatus',
                            ),
                            const SizedBox(height: 8),
                            Text(AppTexts.t('reading.ai_response')),
                            Text(aiResponse),
                            if (audioUrl != null) ...[
                              const SizedBox(height: 8),
                              Text('${AppTexts.t('reading.audio_url')}: $audioUrl'),
                            ],
                            if (shareUrl != null) ...[
                              const SizedBox(height: 8),
                              Text('${AppTexts.t('reading.share_url')}: $shareUrl'),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

