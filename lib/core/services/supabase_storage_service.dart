import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized helper that uploads files to Supabase Storage and returns a
/// public URL that can be stored alongside Firestore records.
class SupabaseStorageService {
  SupabaseStorageService({SupabaseClient? client, String? bucketName})
    : _client = client ?? Supabase.instance.client,
      _bucketName = bucketName ?? _defaultBucket;

  final SupabaseClient _client;
  final String _bucketName;

  static const String _defaultBucket = 'mata3mna';

  /// Uploads the provided [file] under the supplied [pathPrefix] and returns
  /// the publicly accessible URL.
  ///
  ///
  /// The method automatically generates a unique filename to avoid collisions
  /// inside the bucket.
  Future<String> uploadImage({
    required File file,
    required String pathPrefix,
  }) async {
    if (!file.existsSync()) {
      throw Exception('الملف المحدد غير موجود على الجهاز');
    }

    final sanitizedPrefix = pathPrefix.replaceAll(RegExp(r'^/+|/+$'), '');
    final uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final storagePath = '$sanitizedPrefix/$uniqueName';

    try {
      final storage = _client.storage.from(_bucketName);

      // Try to upload with upsert enabled to handle existing files
      await storage.upload(
        storagePath,
        file,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true, // Allow overwriting existing files
        ),
      );

      // Get public URL
      final publicUrl = storage.getPublicUrl(storagePath);
      return publicUrl;
    } on StorageException catch (e) {
      // Helpful debug logging for row-level security or path issues
      // (visible in console during development)
      // ignore: avoid_print
      print(
        '[SupabaseStorage] StorageException while uploading to $_bucketName/$storagePath: ${e.message}',
      );

      // If RLS error, provide more helpful message
      if (e.message.contains('row-level security') ||
          e.message.contains('RLS') ||
          e.message.contains('policy') ||
          e.message.contains('violates row-level security')) {
        throw Exception(
          'فشل رفع الملف: خطأ في صلاحيات Supabase Storage (RLS).\n\n'
          'يجب إضافة سياسة INSERT للمستخدمين ذوي دور "admin" في Supabase Storage.\n\n'
          'افتح Supabase Dashboard:\n'
          '1. اذهب إلى Storage > $_bucketName > Policies\n'
          '2. أضف سياسة INSERT جديدة:\n'
          '   - Policy name: "Allow admin to upload files"\n'
          '   - Allowed operation: INSERT\n'
          '   - Target roles: authenticated\n'
          '   - USING expression: (اتركه فارغاً أو استخدم شرط admin)\n'
          '   - WITH CHECK expression:\n'
          '     EXISTS (\n'
          '       SELECT 1 FROM users\n'
          '       WHERE users.id = auth.uid()\n'
          '       AND users.role = \'admin\'\n'
          '     )\n\n'
          'أو استخدم SQL Editor:\n'
          'CREATE POLICY "Allow admin to upload files"\n'
          'ON storage.objects FOR INSERT\n'
          'TO authenticated\n'
          'WITH CHECK (\n'
          '  bucket_id = \'$_bucketName\' AND\n'
          '  EXISTS (\n'
          '    SELECT 1 FROM users\n'
          '    WHERE users.id = auth.uid()\n'
          '    AND users.role = \'admin\'\n'
          '  )\n'
          ');',
        );
      }

      throw Exception('فشل رفع الملف إلى Supabase: ${e.message}');
    } catch (e) {
      // ignore: avoid_print
      print(
        '[SupabaseStorage] Unexpected error while uploading to $_bucketName/$storagePath: $e',
      );
      throw Exception('حدث خطأ أثناء رفع الملف: $e');
    }
  }

  /// Uploads image bytes under the supplied [pathPrefix] and returns
  /// the publicly accessible URL. This method is useful for web platforms.
  Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String pathPrefix,
    String? fileName,
  }) async {
    final sanitizedPrefix = pathPrefix.replaceAll(RegExp(r'^/+|/+$'), '');
    final uniqueName =
        fileName ?? '${DateTime.now().millisecondsSinceEpoch}_image.jpg';
    final storagePath = '$sanitizedPrefix/$uniqueName';

    try {
      final storage = _client.storage.from(_bucketName);

      // Upload bytes directly
      await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true, // Allow overwriting existing files
        ),
      );

      // Get public URL
      final publicUrl = storage.getPublicUrl(storagePath);
      return publicUrl;
    } on StorageException catch (e) {
      // ignore: avoid_print
      print(
        '[SupabaseStorage] StorageException while uploading bytes to $_bucketName/$storagePath: ${e.message}',
      );

      // If RLS error, provide more helpful message
      if (e.message.contains('row-level security') ||
          e.message.contains('RLS') ||
          e.message.contains('policy') ||
          e.message.contains('violates row-level security')) {
        throw Exception(
          'فشل رفع الملف: خطأ في صلاحيات Supabase Storage (RLS).\n\n'
          'يجب إضافة سياسة INSERT للمستخدمين ذوي دور "admin" في Supabase Storage.\n\n'
          'افتح Supabase Dashboard:\n'
          '1. اذهب إلى Storage > $_bucketName > Policies\n'
          '2. أضف سياسة INSERT جديدة:\n'
          '   - Policy name: "Allow admin to upload files"\n'
          '   - Allowed operation: INSERT\n'
          '   - Target roles: authenticated\n'
          '   - USING expression: (اتركه فارغاً أو استخدم شرط admin)\n'
          '   - WITH CHECK expression:\n'
          '     EXISTS (\n'
          '       SELECT 1 FROM users\n'
          '       WHERE users.id = auth.uid()\n'
          '       AND users.role = \'admin\'\n'
          '     )\n\n'
          'أو استخدم SQL Editor:\n'
          'CREATE POLICY "Allow admin to upload files"\n'
          'ON storage.objects FOR INSERT\n'
          'TO authenticated\n'
          'WITH CHECK (\n'
          '  bucket_id = \'$_bucketName\' AND\n'
          '  EXISTS (\n'
          '    SELECT 1 FROM users\n'
          '    WHERE users.id = auth.uid()\n'
          '    AND users.role = \'admin\'\n'
          '  )\n'
          ');',
        );
      }

      throw Exception('فشل رفع الملف إلى Supabase: ${e.message}');
    } catch (e) {
      // ignore: avoid_print
      print(
        '[SupabaseStorage] Unexpected error while uploading bytes to $_bucketName/$storagePath: $e',
      );
      throw Exception('حدث خطأ أثناء رفع الملف: $e');
    }
  }
}
