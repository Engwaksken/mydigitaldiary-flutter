import 'api_client.dart';

class SearchResult {
  final String module;
  final int id;
  final String title;
  final String? subtitle;

  SearchResult(
      {required this.module,
      required this.id,
      required this.title,
      this.subtitle});

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        module: json['module'],
        id: json['id'],
        title: json['title'] ?? '',
        subtitle: json['subtitle'],
      );
}

class SearchService {
  final _api = ApiClient.instance;

  Future<List<SearchResult>> search(String query) async {
    final response =
        await _api.get('search?q=${Uri.encodeQueryComponent(query)}');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(SearchResult.fromJson).toList();
  }
}
