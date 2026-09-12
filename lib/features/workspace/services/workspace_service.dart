import '../../../services/api_client.dart';
import '../models/workspace_models.dart';

class WorkspaceService {
  final ApiClient _api;

  WorkspaceService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Future<WorkspaceOverview> overview() async {
    final response = await _api.get(
      'workspace',
      cacheable: false,
    );

    if (response is! Map) {
      throw ApiException(
        500,
        'The workspace server returned an unexpected response.',
      );
    }

    final root = Map<String, dynamic>.from(response);
    final dynamic payload = root['data'] ?? root;

    if (payload is! Map) {
      throw ApiException(
        500,
        'The workspace server returned an unexpected response.',
      );
    }

    return WorkspaceOverview.fromJson(
      Map<String, dynamic>.from(payload),
    );
  }

  /// Returns the API path for an authenticated file download.
  ///
  /// Use the app's existing authenticated-download helper when available.
  /// Do not open this URL in a public browser with a bearer token in the URL.
  String fileDownloadPath(int fileId) {
    return 'workspace/files/$fileId/download';
  }
}
