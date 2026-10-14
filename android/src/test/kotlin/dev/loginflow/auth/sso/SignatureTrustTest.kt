package dev.loginflow.auth.sso

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SignatureTrustTest {
    @Test
    fun ownProcessIsTrustedWithoutASignatureLookup() {
        assertTrue(SignatureTrust.isTrustedCaller(10_123, 10_123) { error("not consulted") })
    }

    @Test
    fun otherCallersNeedTheSameCertificate() {
        assertTrue(SignatureTrust.isTrustedCaller(10_200, 10_123) { true })
        assertFalse(SignatureTrust.isTrustedCaller(10_200, 10_123) { false })
    }

    @Test
    fun siblingMustExistBeAnotherPackageAndShareTheCertificate() {
        val sameSigner = setOf("com.acme.admin")
        val check = { pkg: String -> pkg in sameSigner }
        assertTrue(SignatureTrust.isTrustedSibling("com.acme.admin", "com.acme.orders", check))
        assertFalse(SignatureTrust.isTrustedSibling(null, "com.acme.orders", check))
        assertFalse(SignatureTrust.isTrustedSibling("com.acme.orders", "com.acme.orders") { true })
        assertFalse(SignatureTrust.isTrustedSibling("com.attacker.app", "com.acme.orders", check))
    }
}
