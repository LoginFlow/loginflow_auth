import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/members/organization_member.dart';

/// One page of the members of an organization (`GET /v1/app/members`,
/// `doc/server-contract.md` §18).
class MembersPage {
  /// Creates a [MembersPage].
  const MembersPage({required this.items, required this.total});

  /// Reads a [MembersPage] from its JSON form ([toJson]).
  factory MembersPage.fromJson(Map<String, Object?> json) => MembersPage(
    items: List<OrganizationMember>.unmodifiable(
      json.objectList('items').map(OrganizationMember.fromJson),
    ),
    total: json.requireInt('total'),
  );

  /// The members of this page.
  final List<OrganizationMember> items;

  /// Every member matching the query, across pages.
  final int total;

  /// A copy of this [MembersPage] with the given fields replaced.
  MembersPage copyWith({List<OrganizationMember>? items, int? total}) =>
      MembersPage(items: items ?? this.items, total: total ?? this.total);

  /// The JSON form of this [MembersPage], read back by [MembersPage.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'items': items.map((member) => member.toJson()).toList(),
    'total': total,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MembersPage &&
          items.hasSameValues(other.items) &&
          total == other.total;

  @override
  int get hashCode => Object.hash(items.valuesHash, total);
}
