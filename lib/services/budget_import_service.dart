import '../models/budget_import_draft.dart';
import 'api_client.dart';

class BudgetImportService {
  const BudgetImportService();

  Future<BudgetImportDraft> extract({
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) async {
    final response = await ApiClient.instance.postMultipart(
      'budgets/extract',
      fileFieldName: 'file',
      fileBytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );

    dynamic payload = response;
    if (payload is Map && payload['data'] is Map) {
      payload = payload['data'];
    }

    if (payload is! Map) {
      throw ApiException(
        500,
        'Budget extraction returned an invalid response.',
      );
    }

    return BudgetImportDraft.fromJson(
      Map<String, dynamic>.from(payload),
    );
  }

  Future<dynamic> confirm(BudgetImportDraft draft) {
    if (draft.items.isEmpty) {
      throw ApiException(
        422,
        'Add at least one budget line before saving.',
      );
    }

    return ApiClient.instance.post(
      'budgets/import/confirm',
      <String, dynamic>{
        'confidence': draft.confidence,
        'source': draft.source,
        'filename': draft.filename,
        'items': draft.items.map((item) => item.toJson()).toList(),
      },
    );
  }
}
