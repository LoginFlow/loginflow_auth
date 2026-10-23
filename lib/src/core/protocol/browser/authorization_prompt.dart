/// `prompt` values for a browser authorization request
/// (OpenID Connect Core §3.1.2.1, OpenID Connect Prompt Create 1.0).
enum AuthorizationPrompt {
  /// Silent: succeed only with an existing browser session, otherwise
  /// `login_required` (used first on Flutter web, `doc/decisions.md` D10).
  none('none'),

  /// Re-authenticate even with a browser session.
  login('login'),

  /// Open the account creation page (OpenID Connect Prompt Create 1.0).
  create('create'),

  /// Let the user choose among the browser's sessions.
  selectAccount('select_account');

  const AuthorizationPrompt(this.wireName);

  /// The name of this value on the wire.
  final String wireName;
}
