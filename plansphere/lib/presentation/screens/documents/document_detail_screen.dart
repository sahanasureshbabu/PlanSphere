import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/presentation/providers/document_provider.dart';

class DocumentDetailScreen extends ConsumerWidget {
  final String documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(selectedDocumentProvider(documentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'download', child: Text('Download')),
              const PopupMenuItem(value: 'share', child: Text('Share')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppColors.error))),
            ],
            onSelected: (v) async {
              final doc = docAsync.value;
              if (doc == null) return;
              if (v == 'download' && doc.fileUrl != null) {
                await launchUrl(Uri.parse(doc.fileUrl!),
                    mode: LaunchMode.externalApplication);
              } else if (v == 'share') {
                Share.share(
                    'Document: ${doc.title}\nCategory: ${doc.category}');
              } else if (v == 'delete') {
                await ref
                    .read(documentCrudProvider.notifier)
                    .deleteDocument(doc.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: docAsync.when(
        data: (doc) {
          if (doc == null) {
            return const Center(child: Text('Document not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    doc.fileType == 'pdf'
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    size: 72,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(doc.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _DetailRow(
                    label: 'Category', value: doc.category),
                _DetailRow(
                    label: 'File Type',
                    value: doc.fileType?.toUpperCase() ?? 'N/A'),
                if (doc.fileSizeMB != null)
                  _DetailRow(
                      label: 'File Size',
                      value:
                          '${doc.fileSizeMB!.toStringAsFixed(2)} MB'),
                _DetailRow(
                    label: 'Added',
                    value: DateFormat('dd MMM yyyy')
                        .format(doc.createdAt)),
                if (doc.expiryDate != null)
                  _DetailRow(
                    label: 'Expires',
                    value: DateFormat('dd MMM yyyy')
                        .format(doc.expiryDate!),
                    valueColor: doc.isExpired
                        ? AppColors.error
                        : AppColors.success,
                  ),
                if (doc.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Description',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(doc.description),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (doc.fileUrl != null) {
                        await launchUrl(Uri.parse(doc.fileUrl!),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download Document'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: valueColor))),
        ],
      ),
    );
  }
}
