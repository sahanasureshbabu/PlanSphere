import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/presentation/providers/document_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/data/models/document_model.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      AppSnackbar.showError(context, 'Speech recognition not available');
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _query = result.recognizedWords;
            _searchCtrl.text = _query;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN',
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(userBillsProvider).value ?? [];
    final documents = ref.watch(userDocumentsProvider).value ?? [];

    final filteredBills = _filterBills(bills);
    final filteredDocs = _filterDocs(documents);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search bills, documents...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppColors.error
                          : AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color:
                          _isListening ? Colors.white : AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Listening indicator
          if (_isListening)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  const Text('Listening...',
                      style: TextStyle(color: AppColors.error)),
                  const Spacer(),
                  TextButton(
                    onPressed: _toggleListening,
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ).animate().fadeIn(),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _query.isEmpty
                ? _SearchSuggestions(
                    onSuggestionTap: (s) {
                      setState(() {
                        _query = s;
                        _searchCtrl.text = s;
                      });
                    },
                  )
                : _SearchResults(
                    bills: filteredBills,
                    documents: filteredDocs,
                    query: _query,
                  ),
          ),
        ],
      ),
    );
  }

  List<BillModel> _filterBills(List<BillModel> bills) {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();

    // Smart query parsing
    double? minAmount;
    if (q.contains('above ₹') || q.contains('above rs')) {
      final match = RegExp(r'above[^\d]*(\d+)').firstMatch(q);
      if (match != null) minAmount = double.tryParse(match.group(1)!);
    }

    return bills.where((b) {
      if (minAmount != null) return b.amount >= minAmount;
      return b.title.toLowerCase().contains(q) ||
          b.storeName.toLowerCase().contains(q) ||
          b.category.toLowerCase().contains(q) ||
          b.recordType.toLowerCase().contains(q) ||
          b.description.toLowerCase().contains(q) ||
          b.tags.any((t) => t.toLowerCase().contains(q)) ||
          (b.productName?.toLowerCase().contains(q) ?? false) ||
          b.purchaseDate.year.toString().contains(q);
    }).toList();
  }

  List<DocumentModel> _filterDocs(List<DocumentModel> docs) {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return docs.where((d) {
      return d.title.toLowerCase().contains(q) ||
          d.category.toLowerCase().contains(q) ||
          d.description.toLowerCase().contains(q) ||
          d.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }
}

class _SearchSuggestions extends StatelessWidget {
  final Function(String) onSuggestionTap;
  const _SearchSuggestions({required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Samsung bills',
      'Medical bills from 2024',
      'Bills above ₹10000',
      'Expired warranties',
      'Electronics',
      'Insurance documents',
      'Travel tickets',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Try searching for:',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((s) {
            return GestureDetector(
              onTap: () => onSuggestionTap(s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(s,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text('Search Tips',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ...[
          ('🏷️', 'Search by store name', 'e.g. Amazon, Flipkart'),
          ('📅', 'Search by year', 'e.g. 2024, 2025'),
          ('💰', 'Search by amount', 'e.g. bills above ₹10000'),
          ('🎤', 'Use voice search', 'Tap the mic icon'),
        ].map((tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(tip.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tip.$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13)),
                        Text(tip.$3,
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<BillModel> bills;
  final List<DocumentModel> documents;
  final String query;
  const _SearchResults(
      {required this.bills,
      required this.documents,
      required this.query});

  @override
  Widget build(BuildContext context) {
    final total = bills.length + documents.length;
    final currencyFormat = NumberFormat.currency(
        symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    if (total == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No results found',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Try different keywords',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Text(
          '$total results for "$query"',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (bills.isNotEmpty) ...[
          Text('Bills (${bills.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...bills.map((bill) => _BillSearchItem(
                bill: bill,
                currencyFormat: currencyFormat,
              ).animate().fadeIn()),
          const SizedBox(height: 16),
        ],
        if (documents.isNotEmpty) ...[
          Text('Documents (${documents.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...documents.map((doc) =>
              _DocSearchItem(doc: doc).animate().fadeIn()),
        ],
      ],
    );
  }
}

class _BillSearchItem extends StatelessWidget {
  final BillModel bill;
  final NumberFormat currencyFormat;
  const _BillSearchItem(
      {required this.bill, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/bills/${bill.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (AppColors.categoryColors[bill.category] ??
                        AppColors.primary)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: AppColors.categoryColors[bill.category] ??
                    AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${bill.storeName.isNotEmpty ? bill.storeName : bill.category} · ${DateFormat('dd MMM yyyy').format(bill.purchaseDate)}',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              currencyFormat.format(bill.amount),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocSearchItem extends StatelessWidget {
  final DocumentModel doc;
  const _DocSearchItem({required this.doc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/documents/${doc.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                doc.fileType == 'pdf'
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                color: AppColors.info,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(doc.category,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
