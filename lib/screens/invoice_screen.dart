import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/invoice_service.dart';
import '../widgets/common.dart';

class InvoiceScreen extends StatefulWidget {
  final Booking booking;
  const InvoiceScreen({super.key, required this.booking});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late final Future<Uint8List> _pdf = InvoiceService.generate(widget.booking);
  bool _busy = false;
  Future<void> _export(bool print) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await _pdf;
      if (!mounted) return;
      if (print) {
        await Printing.layoutPdf(
          onLayout: (_) async => data,
          name: InvoiceService.filename(widget.booking),
        );
      } else {
        await Printing.sharePdf(
          bytes: data,
          filename: InvoiceService.filename(widget.booking),
        );
      }
    } catch (e) {
      if (mounted) {
        showNotice(
          context,
          'The PDF could not be exported. Check the available print/share apps and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirmation PDF')),
    body: FutureBuilder<Uint8List>(
      future: _pdf,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorState(error: snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _export(false),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Download / share PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _export(true),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print / save PDF'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (_) async => snapshot.data!,
                useActions: false,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                maxPageWidth: 720,
                onError: (context, error) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Preview unavailable on this device. Use Download / share PDF or Print / save PDF above.',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
