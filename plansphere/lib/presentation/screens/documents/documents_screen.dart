import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/document_provider.dart';
import 'package:plansphere/data/models/document_model.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final docsAsync = ref.watch(userDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showUploadSheet(context),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['All', ...AppConstants.documentCategories].map((cat) {
                    final isSelected = _selectedCategory == cat;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.info
                                : Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                        },
                        backgroundColor: Colors.white.withOpacity(0.05),
                        selectedColor: AppColors.info.withAlpha(35),
                        checkmarkColor: AppColors.info,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.info
                              : Colors.grey.withOpacity(0.3),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: docsAsync.when(
                  data: (docs) {
                    final filtered = _selectedCategory == 'All'
                        ? docs
                        : docs.where((d) => d.category == _selectedCategory).toList();

                    if (filtered.isEmpty) {
                      return _EmptyDocs(onAdd: () => _showUploadSheet(context));
                    }

                    final double width = MediaQuery.of(context).size.width;
                    final int crossAxisCount = width < 650
                        ? 2
                        : width < 900
                            ? 3
                            : width < 1200
                                ? 4
                                : 5;

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _DocCard(
                        doc: filtered[i],
                        onDelete: () => _deleteDoc(filtered[i].id),
                      ).animate().fadeIn(delay: (i * 60).ms),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _EmptyDocs(onAdd: () => _showUploadSheet(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDoc(String docId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Document'),
            content: const Text('This will permanently delete the document.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final success =
        await ref.read(documentCrudProvider.notifier).deleteDocument(docId);

    if (mounted) {
      if (success) {
        AppSnackbar.showSuccess(context, 'Document deleted');
      } else {
        AppSnackbar.showError(context, 'Failed to delete document');
      }
    }
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _UploadDocSheet(
        onUpload: (file, title, category) async {
          Navigator.pop(ctx);
          await _uploadDocument(file, title, category);
        },
      ),
    );
  }

  Future<void> _uploadDocument(
    dynamic file,
    String title,
    String category,
  ) async {
    final user = FirebaseAuth.instance.currentUser!;

    final doc = DocumentModel(
      id: '',
      userId: user.uid,
      title: title,
      category: category,
      description: '',
      tags: [],
      hasReminder: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final id = await ref
        .read(documentCrudProvider.notifier)
        .uploadDocument(document: doc, file: file);

    if (mounted) {
      if (id != null) {
        AppSnackbar.showSuccess(context, 'Document uploaded successfully!');
      } else {
        final state = ref.read(documentCrudProvider);
        String message = 'Document upload service is currently unavailable.';
        if (state is AsyncError) {
          final errorStr = state.error.toString().toLowerCase();
          if (errorStr.contains('storage') || errorStr.contains('bucket') || errorStr.contains('object-not-found')) {
            message = 'Storage unavailable.';
          }
        }
        AppSnackbar.showError(context, message);
      }
    }
  }
}

class _DocCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onDelete;

  const _DocCard({
    required this.doc,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = doc.fileType == 'pdf';
    final isExpired = doc.isExpired;
    final color = _getCategoryColor(doc.category);

    return GestureDetector(
      onTap: () => context.push('/documents/${doc.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isExpired
              ? Border.all(color: AppColors.error.withAlpha(80))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        size: 48,
                        color: color,
                      ),
                    ),
                    if (isExpired)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Expired',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPdf ? 'PDF' : 'IMG',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleMedium?.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doc.category,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (doc.fileSizeMB != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${doc.fileSizeMB!.toStringAsFixed(1)} MB',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    return AppColors.categoryColors[category] ?? AppColors.info;
  }
}

class _EmptyDocs extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyDocs({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 72,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No documents yet',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload your important documents\nto keep them safe',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Upload Document'),
          ),
        ],
      ),
    );
  }
}

class _UploadDocSheet extends StatefulWidget {
  final Function(PlatformFile, String, String) onUpload;

  const _UploadDocSheet({required this.onUpload});

  @override
  State<_UploadDocSheet> createState() => _UploadDocSheetState();
}

class _UploadDocSheetState extends State<_UploadDocSheet> {
  final _titleCtrl = TextEditingController();
  String _category = 'Government Documents';
  PlatformFile? _file;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.isNotEmpty) {
      final selectedFile = result.files.single;
      setState(() {
        _file = selectedFile;
        if (_titleCtrl.text.isEmpty) {
          _titleCtrl.text =
              selectedFile.name.replaceAll(RegExp(r'\.[^\.]+$'), '');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Document',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _file != null
                      ? AppColors.successLight.withOpacity(0.15)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _file != null ? AppColors.success : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _file != null
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      color: _file != null ? AppColors.success : AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _file != null
                            ? _file!.name
                            : 'Select PDF or Image',
                        style: TextStyle(
                          color: _file != null
                              ? AppColors.success
                              : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _titleCtrl,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Document Title',
                hintText: 'e.g. Aadhaar Card, Passport',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              items: AppConstants.documentCategories
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _file != null && _titleCtrl.text.isNotEmpty
                    ? () => widget.onUpload(
                          _file!,
                          _titleCtrl.text.trim(),
                          _category,
                        )
                    : null,
                child: const Text('Upload'),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}