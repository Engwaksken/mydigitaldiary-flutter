import '../models/organization.dart';
import 'api_client.dart';

class OrganizationService {
  final _api = ApiClient.instance;

  Future<OrganizationInfo?> show() async {
    final response = await _api.get('organization');
    if (response['data'] == null) return null;
    return OrganizationInfo.fromJson(response['data']);
  }

  Future<String> invite(String email, String role) async {
    final response =
        await _api.post('organization/invite', {'email': email, 'role': role});
    return response['message'] as String;
  }

  Future<void> activate(int memberId) =>
      _api.post('organization/members/$memberId/activate', {});

  Future<void> deactivate(int memberId) =>
      _api.post('organization/members/$memberId/deactivate', {});

  Future<String> replace(int memberId, String newEmail, String newRole) async {
    final response = await _api.post('organization/members/$memberId/replace', {
      'new_email': newEmail,
      'new_role': newRole,
    });
    return response['message'] as String;
  }

  Future<void> removeMember(int memberId) =>
      _api.delete('organization/members/$memberId');
}
