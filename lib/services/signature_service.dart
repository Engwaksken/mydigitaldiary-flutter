import 'dart:convert';
import '../models/signed_document.dart';
import 'api_client.dart';

class SignatureService {
  final _api = ApiClient.instance;

  Future<List<SavedSignature>> signatures() async {
    final response = await _api.get('signatures');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(SavedSignature.fromJson).toList();
  }

  Future<List<SignedDocument>> documents() async {
    final response = await _api.get('signed-documents');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(SignedDocument.fromJson).toList();
  }

  Future<void> deleteDocument(int id) => _api.delete('signed-documents/$id');

  Future<SavedSignature> uploadSignature({required List<int> fileBytes, required String fileName, String? label}) async {
    final response = await _api.postMultipart(
      'signatures',
      fileFieldName: 'signature',
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {if (label != null && label.isNotEmpty) 'label': label},
    );
    return SavedSignature.fromJson(response['data']);
  }


  Future<SavedSignature> saveDrawnSignature({required List<int> pngBytes, String? label}) async {
    final response = await _api.post('signatures', {
      'drawn_signature': 'data:image/png;base64,${base64Encode(pngBytes)}',
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
    });
    return SavedSignature.fromJson(response['data']);
  }

  Future<List<int>> signatureImageBytes(int id) => _api.downloadBytes('signatures/$id/image');

  Future<void> deleteSignature(int id) => _api.delete('signatures/$id');

  Future<void> bulkDeleteDocuments(List<int> ids) => _api.post('signed-documents/bulk-delete', {'document_ids': ids});

  /// Sends the document image, which saved signature to use, and where
  /// to place it (as percentages of the document's dimensions — same
  /// coordinate system the web app's editor uses) in one request. The
  /// server stamps it immediately and returns the result; there's no
  /// separate preview/confirm round-trip since the mobile UI already
  /// shows a live drag preview before this ever gets called.

  Future<Map<String, dynamic>> bundlePages(List<int> documentIds, {String? filename}) async {
    final response = await _api.post('signed-documents/bundle-pages', {
      'document_ids': documentIds,
      if (filename != null && filename.trim().isNotEmpty) 'filename': filename.trim(),
    });
    return Map<String, dynamic>.from(response['data']);
  }

  Future<Map<String, dynamic>> stampImage({
    required List<int> documentBytes,
    required String documentFilename,
    required int signatureId,
    required double xPercent,
    required double yPercent,
    required double widthPercent,
    required double heightPercent,
  }) async {
    final response = await _api.postMultipart(
      'signed-documents/stamp-image',
      fileFieldName: 'document',
      fileBytes: documentBytes,
      fileName: documentFilename,
      fields: {
        'signature_id': signatureId.toString(),
        'x_percent': xPercent.toStringAsFixed(2),
        'y_percent': yPercent.toStringAsFixed(2),
        'width_percent': widthPercent.toStringAsFixed(2),
        'height_percent': heightPercent.toStringAsFixed(2),
      },
    );
    return Map<String, dynamic>.from(response['data']);
  }
}
