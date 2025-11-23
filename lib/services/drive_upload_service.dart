import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class DriveUploadService {
  /// ✅ Isi dengan URL WebApp Apps Script kamu
  static const String scriptUrl =
      'https://script.google.com/macros/s/AKfycbxeZ8puTd-KghdpqkHME9CdZMaGGRTialIC59xc2DkuwaDJojiAAGcvMJPb3msB-AZ4/exec';

  /// ✅ Samakan dengan APP_SECRET di Apps Script
  static const String appSecret =
      '16Xj6czynsgXJGYOmO95Oq2XdZ_jMR17V?usp=drive_link';

  /// Upload menggunakan bytes (AMAN untuk Web & Mobile)
  static Future<Map<String, dynamic>> uploadBytes({
    required Uint8List bytes,
    required String filename,
    required String category,
    String mimeType = 'application/octet-stream',
    String? groupId,
  }) async {
    final base64File = base64Encode(bytes);

    final resp = await http
        .post(
          Uri.parse(scriptUrl),
          body: {
            'secret': appSecret,
            'category': category,
            if (groupId != null) 'groupId': groupId,
            'filename': filename,
            'mimeType': mimeType,
            'fileBase64': base64File,
          },
        )
        .timeout(const Duration(seconds: 60));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode != 200) {
      throw Exception(data['error'] ?? 'Upload failed');
    }

    return data;
  }

  /// OPTIONAL: wrapper Mobile (kalau suatu saat kamu butuh)
  /// Tidak dipakai di Web.
  static Future<Map<String, dynamic>> uploadFile({
    required dynamic file, // File dari dart:io
    required String category,
    String? groupId,
  }) async {
    final bytes = await file.readAsBytes();
    final filename = file.path.toString().split('/').last;
    final mimeType = _mimeFromExt(filename);

    return uploadBytes(
      bytes: bytes,
      filename: filename,
      category: category,
      mimeType: mimeType,
      groupId: groupId,
    );
  }

  static String _mimeFromExt(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}
