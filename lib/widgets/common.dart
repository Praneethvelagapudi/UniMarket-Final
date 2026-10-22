import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app.dart';
import '../models/models.dart';
import '../services/errors.dart';

void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(friendlyError(error)),
        behavior: SnackBarBehavior.floating,
      ),
    );
void showNotice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
Future<bool> confirmAction(
  BuildContext context,
  String title,
  String body,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  final Object error;
  const ErrorState({super.key, required this.error});
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.wifi_off_rounded,
    title: 'Unable to load',
    body: friendlyError(error),
  );
}

class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  const BusyButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.label,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
    label: Text(label),
  );
}

class ItemImage extends StatelessWidget {
  final String url, category;
  final double? height;
  const ItemImage({
    super.key,
    required this.url,
    required this.category,
    this.height,
  });
  @override
  Widget build(BuildContext context) {
    final icon = switch (category) {
      'Books' => Icons.menu_book_rounded,
      'Electronics' => Icons.memory_rounded,
      'Lab equipment' => Icons.science_rounded,
      'Stationery' => Icons.draw_rounded,
      _ => Icons.inventory_2_rounded,
    };
    final placeholder = Container(
      height: height,
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .5),
      child: Center(
        child: Icon(
          icon,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    if (url.startsWith('firestore:')) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppScope.of(context).market.db
            .collection('listing-images')
            .doc(url.substring(10))
            .snapshots(),
        builder: (context, snapshot) {
          final encoded = snapshot.data?.data()?['data'] as String?;
          if (encoded == null) return placeholder;
          try {
            return Image.memory(
              base64Decode(encoded),
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            );
          } catch (_) {
            return placeholder;
          }
        },
      );
    }
    return url.isEmpty
        ? placeholder
        : Image.network(
            url,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : placeholder,
          );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  const StatusPill(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    ),
  );
}

class ListingCard extends StatelessWidget {
  final Listing item;
  final VoidCallback onTap;
  const ListingCard({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ItemImage(url: item.imageUrl, category: item.category),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: StatusPill(item.department),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${item.condition} · ${item.ownerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                if (item.salePrice > 0)
                  Text(
                    '${money(item.salePrice)} to buy',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (item.dailyRate > 0)
                  Text(
                    '${money(item.dailyRate)} / day',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CacheBanner extends StatelessWidget {
  final bool cached;
  const CacheBanner({super.key, required this.cached});
  @override
  Widget build(BuildContext context) => cached
      ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Saved on this device · checking for updates',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        )
      : const SizedBox.shrink();
}
