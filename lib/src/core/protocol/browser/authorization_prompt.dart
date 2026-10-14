/// `prompt` values for a browser authorization request
/// (OpenID Connect Core §3.1.2.1, OpenID Connect Prompt Create 1.0).
enum AuthorizationPrompt {
  /// Silent: succeed only with an existing browser session, otherwise
  /// `login_required` (used first on Flutter web, `doc/decisions.md` D10).
  none('none'),
  login('login'),
  create('create'),
  selectAccount('select_account');

  const AuthorizationPrompt(this.wireName);

  final String wireName;
}
