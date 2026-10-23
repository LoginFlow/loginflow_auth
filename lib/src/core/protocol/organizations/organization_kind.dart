/// Where an organization sits in its application (`kind`,
/// `doc/server-contract.md` §17).
enum OrganizationKind {
  /// The application as a whole inside its LoginFlow company: one per
  /// application, with no `external_id`. Platform staff work here.
  root('root'),

  /// An organization the product created (a client company, a school),
  /// identified by the product's own `external_id`.
  regular('regular');

  const OrganizationKind(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// Throws a [FormatException] for any other value: the server only sends
  /// these two.
  static OrganizationKind fromWireName(String value) {
    for (final kind in values) {
      if (kind.wireName == value) {
        return kind;
      }
    }
    throw FormatException('Unknown organization kind "$value".');
  }
}
