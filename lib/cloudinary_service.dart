// lib/services/cloudinary_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName    = 'dansgebcx';
  static const String _uploadPreset = 'zad_docs';

  /// يرفع أي ملف ويرجع الـ URL أو null في حالة الخطأ
  /// resourceType: 'image' للصور، 'raw' للـ PDF
  static Future<String?> uploadFile(
    File file, {
    String resourceType = 'image',
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final body = jsonDecode(await streamedResponse.stream.bytesToString());

      if (streamedResponse.statusCode == 200) {
        return body['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// يختار تلقائياً resource type حسب الامتداد
  static Future<String?> uploadAuto(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final resourceType = ext == 'pdf' ? 'raw' : 'image';
    return uploadFile(file, resourceType: resourceType);
  }
}