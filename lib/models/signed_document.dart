class SignedDocument {
  final int id;
  final String originalFilename;
  final bool wasStamped;
  final String? stampError;
  final int pageCount;
  final int placementCount;
  final String? signedAt;
  final String downloadUrl;

  SignedDocument({
    required this.id,
    required this.originalFilename,
    required this.wasStamped,
    this.stampError,
    required this.pageCount,
    required this.placementCount,
    this.signedAt,
    required this.downloadUrl,
  });

  factory SignedDocument.fromJson(Map<String, dynamic> json) => SignedDocument(
        id: json['id'],
        originalFilename: json['original_filename'] ?? '',
        wasStamped: json['was_stamped'] ?? false,
        stampError: json['stamp_error'],
        pageCount: json['page_count'] ?? 0,
        placementCount: json['placement_count'] ?? 0,
        signedAt: json['signed_at'],
        downloadUrl: json['download_url'] ?? '',
      );
}

class SavedSignature {
  final int id;
  final String label;
  final String url;

  SavedSignature({required this.id, required this.label, required this.url});

  factory SavedSignature.fromJson(Map<String, dynamic> json) =>
      SavedSignature(id: json['id'], label: json['label'] ?? '', url: json['url'] ?? '');
}
