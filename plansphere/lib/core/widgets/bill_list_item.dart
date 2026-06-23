import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/data/models/bill_model.dart';

class BillListItem extends StatelessWidget {
  final BillModel bill;
  final VoidCallback? onDelete;

  const BillListItem({
    super.key,
    required this.bill,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        AppColors.categoryColors[bill.category] ?? AppColors.primary;
    final currencyFormat = NumberFormat.currency(
        symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return GestureDetector(
      onTap: () => context.push('/bills/${bill.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(bill.category),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Bill info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bill.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        currencyFormat.format(bill.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bill.storeName.isNotEmpty
                              ? bill.storeName
                              : bill.category,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yy').format(bill.purchaseDate),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (bill.hasWarranty) ...[
                    const SizedBox(height: 6),
                    _WarrantyBadge(bill: bill),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Actions
            if (onDelete != null)
              PopupMenuButton(
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.grey[400], size: 20),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View Details'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'view') {
                    context.push('/bills/${bill.id}');
                  } else if (value == 'edit') {
                    context.push('/bills/${bill.id}/edit');
                  } else if (value == 'delete') {
                    onDelete!();
                  }
                },
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    const icons = {
      'Electronics': Icons.devices_rounded,
      'Appliances': Icons.kitchen_rounded,
      'Food & Grocery': Icons.shopping_basket_rounded,
      'Medical': Icons.local_hospital_rounded,
      'Travel': Icons.flight_rounded,
      'Insurance': Icons.security_rounded,
      'Education': Icons.school_rounded,
      'Utilities': Icons.electrical_services_rounded,
      'Fuel': Icons.local_gas_station_rounded,
      'Entertainment': Icons.movie_rounded,
      'Clothing': Icons.checkroom_rounded,
      'Home & Garden': Icons.home_rounded,
      'Automobile': Icons.directions_car_rounded,
    };
    return icons[category] ?? Icons.receipt_long_rounded;
  }
}

class _WarrantyBadge extends StatelessWidget {
  final BillModel bill;
  const _WarrantyBadge({required this.bill});

  @override
  Widget build(BuildContext context) {
    final status = bill.warrantyStatus;
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case WarrantyStatus.active:
        color = AppColors.success;
        label = 'Warranty Active';
        icon = Icons.verified_rounded;
        break;
      case WarrantyStatus.expiringSoon:
        color = AppColors.warning;
        label =
            'Expires in ${bill.daysUntilWarrantyExpiry} days';
        icon = Icons.warning_amber_rounded;
        break;
      case WarrantyStatus.expired:
        color = AppColors.error;
        label = 'Warranty Expired';
        icon = Icons.cancel_rounded;
        break;
      default:
        return const SizedBox();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
