/// The one definition of a LoginFlow access code every app shares
/// (`doc/server-contract.md` §16): [length] characters from [alphabet],
/// case-insensitive, shown as `XXXX-XXXX`; spaces and dashes in the input
/// are ignored.
///
/// The server hashes the normalized value, so any app that sends
/// [normalize]'d input matches what the tenant backend handed out.
abstract final class AccessCodeFormat {
  /// Uppercase letters and digits without the look-alikes 0, O, 1, I and L,
  /// so a code read aloud or copied from paper is typed right.
  static const String alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  /// How many characters a normalized code has.
  static const int length = 8;

  /// Characters before the [separator] in the displayed form.
  static const int groupLength = 4;

  /// The dash shown between the two halves of a code (`XXXX-XXXX`).
  static const String separator = '-';

  static final RegExp _ignored = RegExp(r'[\s-]');

  /// [input] uppercased, without spaces and dashes — the value to send.
  /// Other characters are kept, so a malformed code stays malformed and
  /// [isComplete] rejects it.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(_ignored, '');

  /// Only the [alphabet] characters of [input], uppercased, at most
  /// [length] — what a text field accepts while the user types or pastes.
  static String filter(String input) => input
      .toUpperCase()
      .split('')
      .where(alphabet.contains)
      .take(length)
      .join();

  /// Whether [input], once [normalize]d, is exactly [length] characters of
  /// [alphabet]: the only shape the server ever issues.
  static bool isComplete(String input) {
    final code = normalize(input);
    return code.length == length && code.split('').every(alphabet.contains);
  }

  /// [input] [normalize]d and grouped as `XXXX-XXXX`; partial input gets
  /// the [separator] once it has more than [groupLength] characters.
  static String display(String input) {
    final code = normalize(input);
    if (code.length <= groupLength) {
      return code;
    }
    return '${code.substring(0, groupLength)}$separator'
        '${code.substring(groupLength)}';
  }
}
