import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/organizations/organization_kind.dart';

/// An organization of the application where the signed-in user has at
/// least one active assignment (`GET {organizations_endpoint}`,
/// `doc/server-contract.md` §17).
class Organization {
  /// Creates an [Organization].
  const Organization({
    required this.id,
    required this.name,
    required this.kind,
    this.externalId,
  });

  /// Reads an [Organization] from its JSON form ([toJson]).
  factory Organization.fromJson(Map<String, Object?> json) => Organization(
    id: json.requireString('id'),
    name: json.requireString('name'),
    kind: OrganizationKind.fromWireName(json.requireString('kind')),
    externalId: json.optionalString('external_id'),
  );

  /// LoginFlow's identifier: what `LoginFlowAuth.switchOrganization` and the
  /// sign-in `organization` parameter take.
  final String id;

  /// The display name.
  final String name;

  /// `root` (the application itself) or `regular` (created by the product).
  final OrganizationKind kind;

  /// The product's own identifier, `null` for the root organization.
  final String? externalId;

  /// A copy of this [Organization] with the given fields replaced.
  Organization copyWith({
    String? id,
    String? name,
    OrganizationKind? kind,
    String? externalId,
  }) => Organization(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    externalId: externalId ?? this.externalId,
  );

  /// The JSON form of this [Organization], read back by [Organization.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'kind': kind.wireName,
    'external_id': externalId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organization &&
          id == other.id &&
          name == other.name &&
          kind == other.kind &&
          externalId == other.externalId;

  @override
  int get hashCode => Object.hash(id, name, kind, externalId);
}
