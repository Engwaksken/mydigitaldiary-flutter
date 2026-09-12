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
  }) async {
    dynamic response;

    if (photoBytes != null && photoFilename != null) {
      response = await _api.postMultipart(
        'business-card',
        fileFieldName: 'photo',
        fileBytes: photoBytes,
        fileName: photoFilename,
        contentType: _imageContentType(photoFilename),
        fields: card.toFormFields(),
      );
    } else {
      response = await _api.post('business-card', card.toFormFields());
    }

    return BusinessCard.fromJson(Map<String, dynamic>.from(response['data']));
  }

  Future<BusinessCard> togglePublished() async {
    final response = await _api.post('business-card/toggle-published', {});
    return BusinessCard.fromJson(Map<String, dynamic>.from(response['data']));
  }

  Future<List<int>> photoBytes() => _api.downloadBytes('business-card/photo');

  Future<List<int>> downloadPdfBytes() =>
      _api.downloadBytes('business-card/pdf');

  String _imageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
