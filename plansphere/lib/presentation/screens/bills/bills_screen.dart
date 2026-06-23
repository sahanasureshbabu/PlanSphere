import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/bill_list_item.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'date_desc';
  final _searchCtrl = TextEditingController();

  List<BillModel> _filterAndSort(List<BillModel> bills) {
    var filtered = bills.where((b) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          b.title.toLowerCase().contains(q) ||
          b.storeName.toLowerCase().contains(q) ||
          b.category.toLowerCase().contains(q) ||
          b.tags.any((t) => t.toLowerCase().contains(q));
      final matchesCategory =
          _selectedCategory == 'All' || b.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    switch (_sortBy) {
      case 'date_asc':
        filtered.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
        break;
      case 'date_desc':
        filtered.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
        break;
      case 'amount_asc':
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'amount_desc':
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'name_asc':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return filtered;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
    final billsAsync = ref.watch(userBillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortSheet,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/bills/add'),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search bills...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

              // Category filter chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['All', ...AppConstants.billCategories].map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        backgroundColor: Colors.transparent,
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        checkmarkColor: AppColors.primary,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.withOpacity(0.3),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : null,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              // Bills list
              Expanded(
                child: billsAsync.when(
                  data: (bills) {
                    final filtered = _filterAndSort(bills);
                    if (filtered.isEmpty) {
                      return _EmptyBills(
                        hasSearch: _searchQuery.isNotEmpty,
                        onAdd: () => context.push('/bills/add'),
                      );
                    }

                    final isWide = MediaQuery.of(context).size.width >= 650;
                    if (isWide) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 500,
                          mainAxisExtent: 115,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 0,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => BillListItem(
                          bill: filtered[i],
                          onDelete: () => _deleteBill(filtered[i]),
                        ).animate().fadeIn(delay: (i * 50).ms),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => BillListItem(
                        bill: filtered[i],
                        onDelete: () => _deleteBill(filtered[i]),
                      ).animate().fadeIn(delay: (i * 50).ms),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _EmptyBills(
                    hasSearch: _searchQuery.isNotEmpty,
                    onAdd: () => context.push('/bills/add'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBill(BillModel bill) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Bill'),
              content: loading
                  ? const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const Text(
                      'Are you sure you want to delete this bill? This action cannot be undone.'),
              actions: loading
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          setDialogState(() {
                            loading = true;
                          });
                          try {
                            await ref
                                .read(billServiceProvider)
                                .deleteBill(bill.id, bill.userId);
                            ref.invalidate(userBillsProvider);
                            ref.invalidate(activeWarrantiesProvider);
                            ref.invalidate(expiringSoonWarrantiesProvider);

                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              AppSnackbar.showSuccess(
                                  context, 'Bill deleted successfully');
                            }
                          } catch (e) {
                            debugPrint('Delete bill error: $e');
                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              AppSnackbar.showError(context, e.toString());
                            }
                          }
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort By',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...[
              ('date_desc', 'Newest First'),
              ('date_asc', 'Oldest First'),
              ('amount_desc', 'Highest Amount'),
              ('amount_asc', 'Lowest Amount'),
              ('name_asc', 'Name A-Z'),
            ].map((item) => ListTile(
                  title: Text(item.$2),
                  leading: Radio<String>(
                    value: item.$1,
                    groupValue: _sortBy,
                    onChanged: (v) {
                      setState(() => _sortBy = v!);
                      Navigator.pop(ctx);
                    },
                    activeColor: AppColors.primary,
                  ),
                  onTap: () {
                    setState(() => _sortBy = item.$1);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onAdd;
  const _EmptyBills({required this.hasSearch, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.receipt_long_rounded,
            size: 72,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No results found' : 'No bills yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try a different search term'
                : 'Add your first bill to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Bill'),
            ),
          ],
        ],
      ),
    );
  }
}
