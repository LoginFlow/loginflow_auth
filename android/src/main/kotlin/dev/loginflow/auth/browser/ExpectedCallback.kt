package dev.loginflow.auth.browser

/**
 * The only navigation that completes the pending authorization: the
 * registered redirect URI (scheme, host, path; RFC 9700 §4.1.3 exact match)
 * carrying the request's `state` (RFC 6749 §10.12).
 */
internal data class ExpectedCallback(
    val scheme: String,
    val host: String,
    val path: String,
    val state: String,
) {
    /**
     * Pure decision, testable on the JVM. Scheme and host compare
     * case-insensitively (RFC 3986 §6.2.2.1); path and state exactly.
     */
    fun matches(scheme: String?, host: String?, path: String?, state: String?): Boolean =
        scheme.orEmpty().equals(this.scheme, ignoreCase = true) &&
            host.orEmpty().equals(this.host, ignoreCase = true) &&
            path.orEmpty() == this.path &&
            state == this.state
}
