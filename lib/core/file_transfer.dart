import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Offers an export to the platform share sheet, or downloads it on the web.
/// The browser and operating system retain control over the destination.
Future<void> deliverFile(
  BuildContext context, {
  required String content,
  required String filename,
  required String mimeType,
}) async {
  final file = XFile.fromData(
    Uint8List.fromList(utf8.encode(content)),
    name: filename,
    mimeType: mimeType,
  );
  final renderBox = context.findRenderObject();
  final screen = Offset.zero & MediaQuery.sizeOf(context);
  final candidate = renderBox is RenderBox && renderBox.hasSize
      ? (renderBox.localToGlobal(Offset.zero) & renderBox.size).intersect(
          screen,
        )
      : screen;
  final origin = candidate.isEmpty
      ? Rect.fromCenter(center: screen.center, width: 1, height: 1)
      : candidate;
  String message;
  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [filename],
        sharePositionOrigin: origin,
        downloadFallbackEnabled: true,
      ),
    );
    message = switch (result.status) {
      ShareResultStatus.dismissed => 'Export canceled.',
      ShareResultStatus.success => 'Export opened. Save it in your chosen app.',
      ShareResultStatus.unavailable =>
        kIsWeb
            ? 'Download requested. Check your browser’s downloads.'
            : 'Export requested. Check the share sheet or your selected destination.',
    };
  } catch (_) {
    if (!kIsWeb) rethrow;
    // Some browsers expose sharing but reject files. CrossFile uses a browser
    // download with a Blob URL, without requiring a server or uploading data.
    try {
      await file.saveTo(filename);
      message = 'Download requested. Check your browser’s downloads.';
    } catch (_) {
      throw StateError(
        'This browser could not export the file. Try another browser.',
      );
    }
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
