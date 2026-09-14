import '../models/meeting.dart';
import 'api_client.dart';

class MeetingPage {
  final List<Meeting> meetings;
  final int currentPage;
  final int lastPage;
  final int total;

  const MeetingPage({
    required this.meetings,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

class MeetingService {
  final _api = ApiClient.instance;

   Future<MeetingPage> list({
    int page = 1,
    int perPage = 10,
    String? search,
    String? status,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final response = await _api.get('meetings?$query', cacheable: true);
    final rows =
        (response['data'] as List? ?? const []).cast<Map<String, dynamic>>();

    return MeetingPage(
      meetings: rows.map(Meeting.fromJson).toList(),
      currentPage: (response['current_page'] as num?)?.toInt() ?? page,
      lastPage: (response['last_page'] as num?)?.toInt() ?? 1,
      total: (response['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  Future<Meeting> create(Meeting meeting) async {
    final response = await _api.post('meetings', meeting.toJson());
    return Meeting.fromJson(response);
  }

  Future<Meeting> update(int id, Meeting meeting) async {
    final response = await _api.put('meetings/$id', meeting.toJson());
    return Meeting.fromJson(response);
  }

  Future<void> delete(int id) => _api.delete('meetings/$id');
}
