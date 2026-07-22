import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/presentation/providers/document_provider.dart';
import 'package:plansphere/core/utils/file_saver_helper.dart';
import 'package:plansphere/core/utils/responsive_layout.dart';

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

          final isWide = ResponsiveLayout.isWide(context);
          if (isWide) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (40% width) - Preview & Actions
                    Expanded(
                      flex: 4,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 300,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              child: _buildPreview(context, doc, isWide: true),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Actions',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _downloadDocument(context, doc),
                                      icon: const Icon(Icons.download_rounded),
                                      label: const Text('Download Document'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Share.share(
                                                'Document: ${doc.title}\nCategory: ${doc.category}');
                                          },
                                          icon: const Icon(Icons.share_rounded),
                                          label: const Text('Share'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            await ref
                                                .read(documentCrudProvider.notifier)
                                                .deleteDocument(doc.id);
                                            if (context.mounted) context.pop();
                                          },
                                          icon: const Icon(Icons.delete_rounded,
                                              color: AppColors.error),
                                          label: const Text('Delete',
                                              style: TextStyle(
                                                  color: AppColors.error)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: AppColors.error),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right Column (60% width) - Details & Info
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 20),
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
                              const SizedBox(height: 24),
                              Text('Description',
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              Text(doc.description,
                                  style: const TextStyle(fontSize: 14, height: 1.5)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildPreview(context, doc, isWide: false),
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
                    onPressed: () => _downloadDocument(context, doc),
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () => context.pop(),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.error_outline_rounded,
                  size: 72,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load document details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(selectedDocumentProvider(documentId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
  }

  Widget _buildPreview(BuildContext context, DocumentModel doc, {required bool isWide}) {
    final url = doc.fileUrl ?? '';
    final isPdf = doc.fileType == 'pdf';

    if (url.startsWith('data:image/')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.broken_image_rounded,
            size: isWide ? 96 : 72,
            color: AppColors.primary,
          ),
        );
      } catch (e) {
        return Icon(
          Icons.image_rounded,
          size: isWide ? 96 : 72,
          color: AppColors.primary,
        );
      }
    } else if (url.startsWith('http') && !isPdf) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image_rounded,
          size: isWide ? 96 : 72,
          color: AppColors.primary,
        ),
      );
    }

    return Icon(
      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
      size: isWide ? 96 : 72,
      color: AppColors.primary,
    );
  }

  Future<void> _downloadDocument(BuildContext context, DocumentModel doc) async {
    final url = doc.fileUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file available to download')),
      );
      return;
    }

    if (url.startsWith('data:')) {
      try {
        final parts = url.split(',');
        final base64String = parts.last;
        final bytes = base64Decode(base64String);
        
        String ext = doc.fileType ?? 'bin';
        final mimeType = url.substring(5, url.indexOf(';'));
        final fileName = '${doc.title.replaceAll(RegExp(r"[^\w\-_]"), "_")}.$ext';

        await FileSaverHelper.saveFile(
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download started for $fileName')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
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
