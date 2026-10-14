package dev.loginflow.auth.browser

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ExpectedCallbackTest {
    private val appLink = ExpectedCallback("https", "acme.example.com", "/oauth/callback", "s-123")
    private val privateScheme = ExpectedCallback("com.acme.orders", "", "/oauth/callback", "s-123")

    @Test
    fun theRegisteredRedirectWithTheRequestStateMatches() {
        assertTrue(appLink.matches("https", "acme.example.com", "/oauth/callback", "s-123"))
        assertTrue(appLink.matches("HTTPS", "ACME.example.com", "/oauth/callback", "s-123"))
        assertTrue(privateScheme.matches("com.acme.orders", null, "/oauth/callback", "s-123"))
    }

    @Test
    fun aForgedStateIsNotConsumed() {
        assertFalse(appLink.matches("https", "acme.example.com", "/oauth/callback", "forged"))
        assertFalse(appLink.matches("https", "acme.example.com", "/oauth/callback", null))
    }

    @Test
    fun anotherSchemeHostOrPathIsNotConsumed() {
        assertFalse(appLink.matches("http", "acme.example.com", "/oauth/callback", "s-123"))
        assertFalse(appLink.matches("https", "evil.example", "/oauth/callback", "s-123"))
        assertFalse(appLink.matches("https", "acme.example.com", "/oauth/callback2", "s-123"))
        assertFalse(privateScheme.matches("com.evil.app", null, "/oauth/callback", "s-123"))
    }
}
