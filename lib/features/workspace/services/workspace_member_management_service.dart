import '../../../services/api_client.dart';
import '../models/workspace_member_management_models.dart';

class WorkspaceMemberManagementService {
  final ApiClient _api;

  WorkspaceMemberManagementService({
    ApiClient? api,
  }) : _api = api ?? ApiClient.instance;

  Future<WorkspaceMemberManagement> load() async {
    final response = await _api.get(
      'organization',
      cacheable: false,
    );

    final root = _map(response);
    final raw = root['data'];

    if (raw is! Map) {
      throw ApiException(
        403,
        (root['message'] ??
                'Member management is not available for this subscription.')
            .toString(),
      );
    }

    return WorkspaceMemberManagement.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<String> invite({
    required String name,
    required String email,
    required String role,
    required String temporaryPassword,
  }) async {
    final response = await _api.post(
      'organization/invite',
      {
        'name': name.trim(),
        'email': email.trim(),
        'role': role,
        'temporary_password': temporaryPassword,
        'temporary_password_confirmation': temporaryPassword,
      },
    );

    return _message(
      response,
      'Member added successfully.',
    );
  }

  Future<String> editMember({
    required int membershipId,
    required String email,
    required String role,
  }) async {
    final response = await _api.put(
      'organization/members/$membershipId',
      {
        'email': email.trim(),
        'role': role,
      },
    );

    return _message(
      response,
      'Member workspace details updated.',
    );
  }

  Future<String> updateRole(
    int membershipId,
    String role,
  ) async {
    final response = await _api.put(
      'organization/members/$membershipId/role',
      {'role': role},
    );

    return _message(response, 'Member role updated.');
  }

  Future<String> suspend(int membershipId) async {
    final response = await _api.post(
      'organization/members/$membershipId/deactivate',
      const {},
    );

    return _message(response, 'Member access suspended.');
  }

  Future<String> activate(int membershipId) async {
    final response = await _api.post(
      'organization/members/$membershipId/activate',
      const {},
    );

    return _message(response, 'Member reactivated.');
  }

  Future<String> remove(int membershipId) async {
    final response = await _api.delete(
      'organization/members/$membershipId',
    );

    return _message(response, 'Member removed.');
  }

  Map<String, dynamic> _map(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      500,
      'The server returned an unexpected member-management response.',
    );
  }

  String _message(dynamic response, String fallback) {
    if (response is Map && response['message'] != null) {
      return response['message'].toString();
    }

    return fallback;
  }
}
