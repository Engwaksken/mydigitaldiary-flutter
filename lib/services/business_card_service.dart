import '../models/business_card.dart';
import 'api_client.dart';

class BusinessCardService {
  final _api = ApiClient.instance;

  Future<BusinessCard?> show() async {
    final response = await _api.get('business-card');
    if (response['data'] == null) return null;
    return BusinessCard.fromJson(Map<String, dynamic>.from(response['data']));
  }

  Future<BusinessCard> save(
    BusinessCard card, {
    List<int>? photoBytes,
    String? photoFilename,
    List<int>? logoBytes,
    String? logoFilename,
    bool removeLogo = false,
  }) async {
    dynamic response;

    final files = <MultipartUploadFile>[
      if (photoBytes != null && photoFilename != null)
        MultipartUploadFile(
          fieldName: 'photo',
          bytes: photoBytes,
          fileName: photoFilename,
          contentType: _imageContentType(photoFilename),
        ),
      if (logoBytes != null && logoFilename != null)
        MultipartUploadFile(
          fieldName: 'logo',
          bytes: logoBytes,
          fileName: logoFilename,
          contentType: _imageContentType(logoFilename),
        ),
    ];

    final fields = card.toFormFields();
    if (removeLogo) fields['remove_logo'] = '1';

    if (files.isNotEmpty) {
      response = await _api.multipart(
        'business-card',
        fileFieldName: files.first.fieldName,
        fileBytes: files.first.bytes,
        fileName: files.first.fileName,
        contentType: files.first.contentType,
        fields: fields,
        files: files.sublist(1),
      );
    } else {
      response = await _api.post('business-card', fields);
    }

    return BusinessCard.fromJson(Map<String, dynamic>.from(response['data']));
  }

  Future<BusinessCard> togglePublished() async {
    final response = await _api.post('business-card/toggle-published', {});
    return BusinessCard.fromJson(Map<String, dynamic>.from(response['data']));
  }

  Future<List<int>> photoBytes() => _api.downloadBytes('business-card/photo');

  Future<List<int>> logoBytes() => _api.downloadBytes('business-card/logo');

  Future<List<int>> downloadPdfBytes() =>
      _api.downloadBytes('business-card/pdf');

  String _imageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
