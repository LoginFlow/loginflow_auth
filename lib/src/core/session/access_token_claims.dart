import 'package:loginflow_auth/src/core/jose/compact_jws.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// What an API access token says about the active organization and the
/// permissions the user holds there for that API (`org_id`, `org_ext`,
/// `permissions`, `permissions_overage`; `doc/server-contract.md` §17).
///
/// UI ONLY. Decoded from the token WITHOUT verifying its signature: use it to
/// show or hide parts of the interface, never to decide access. The API
/// that receives the token verifies it and is the only authority on what
/// the user may do.
class AccessTokenClaims {
  const AccessTokenClaims({
    this.organizationId,
    this.organizationExternalId,
    this.permissions = const <String>[],
    this.isPermissionsOverage = false,
  });

  factory AccessTokenClaims.fromJson(Map<String, Object?> json) =>
      AccessTokenClaims(
        organizationId: json.optionalString('org_id'),
        organizationExternalId: json.optionalString('org_ext'),
        permissions: json.stringList('permissions'),
        isPermissionsOverage: json.optionalBool(
          'permissions_overage',
          absent: false,
        ),
      );

  /// The claims of [accessToken], or `null` when it is not a JWT with a JSON
  /// object payload (an opaque token). The signature is NOT checked.
  static AccessTokenClaims? decode(String accessToken) =>
      CompactJws.parse(accessToken).when(
        ok: (jws) {
          try {
            return AccessTokenClaims.fromJson(jws.claims);
          } on FormatException {
            return null;
          }
        },
        err: (_) => null,
      );

  /// The active organization (`org_id`), or `null` when the user has none
  /// selected: list them with `LoginFlowAuth.listOrganizations` and choose
  /// one with `LoginFlowAuth.switchOrganization`.
  final String? organizationId;

  /// The product's own identifier of the active organization (`org_ext`),
  /// `null` for the application's root organization.
  final String? organizationExternalId;

  /// The user's permissions for this API in the active organization. Empty
  /// when no organization is active, and when [isPermissionsOverage].
  final List<String> permissions;

  /// The permissions did not fit in the token; only the API can resolve
  /// them (through introspection). [permissions] is empty then.
  final bool isPermissionsOverage;

  AccessTokenClaims copyWith({
    String? organizationId,
    String? organizationExternalId,
    List<String>? permissions,
    bool? isPermissionsOverage,
  }) => AccessTokenClaims(
    organizationId: organizationId ?? this.organizationId,
    organizationExternalId:
        organizationExternalId ?? this.organizationExternalId,
    permissions: permissions ?? this.permissions,
    isPermissionsOverage: isPermissionsOverage ?? this.isPermissionsOverage,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'org_id': ?organizationId,
    'org_ext': ?organizationExternalId,
    'permissions': permissions,
    'permissions_overage': isPermissionsOverage,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessTokenClaims &&
          organizationId == other.organizationId &&
          organizationExternalId == other.organizationExternalId &&
          permissions.hasSameValues(other.permissions) &&
          isPermissionsOverage == other.isPermissionsOverage;

  @override
  int get hashCode => Object.hash(
    organizationId,
    organizationExternalId,
    permissions.valuesHash,
    isPermissionsOverage,
  );
}
