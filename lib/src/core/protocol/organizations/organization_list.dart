import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/organizations/organization.dart';

/// The organizations the signed-in user can work in for this application,
/// and the one the session has active (`GET {organizations_endpoint}`,
/// `doc/server-contract.md` §17).
class OrganizationList {
  const OrganizationList({
    required this.organizations,
    this.activeOrganizationId,
  });

  factory OrganizationList.fromJson(Map<String, Object?> json) {
    final rawOrganizations = json['organizations'];
    if (rawOrganizations is! List<Object?> ||
        !rawOrganizations.every((entry) => entry is Map<String, Object?>)) {
      throw const FormatException(
        'Field "organizations" must be an array of objects.',
      );
    }
    return OrganizationList(
      organizations: List<Organization>.unmodifiable(
        rawOrganizations.cast<Map<String, Object?>>().map(
          Organization.fromJson,
        ),
      ),
      activeOrganizationId: json.optionalString('active'),
    );
  }

  final List<Organization> organizations;

  /// The [Organization.id] the session's tokens are issued for, or `null`
  /// when none is selected (the user holds roles in zero or several
  /// organizations and none was chosen).
  final String? activeOrganizationId;

  /// The active entry of [organizations], when there is one.
  Organization? get activeOrganization {
    for (final organization in organizations) {
      if (organization.id == activeOrganizationId) {
        return organization;
      }
    }
    return null;
  }

  OrganizationList copyWith({
    List<Organization>? organizations,
    String? activeOrganizationId,
  }) => OrganizationList(
    organizations: organizations ?? this.organizations,
    activeOrganizationId: activeOrganizationId ?? this.activeOrganizationId,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'active': activeOrganizationId,
    'organizations': organizations
        .map((organization) => organization.toJson())
        .toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationList &&
          organizations.hasSameValues(other.organizations) &&
          activeOrganizationId == other.activeOrganizationId;

  @override
  int get hashCode =>
      Object.hash(organizations.valuesHash, activeOrganizationId);
}
