package dev.loginflow.auth.storage

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CiphertextLayoutTest {
    @Test
    fun refusesInputShorterThanIvPlusTag() {
        assertFalse(CiphertextLayout.isWellFormed(ByteArray(0)))
        assertFalse(CiphertextLayout.isWellFormed(ByteArray(11)))
        assertFalse(CiphertextLayout.isWellFormed(ByteArray(27)))
    }

    @Test
    fun acceptsIvPlusTagAndLonger() {
        assertTrue(CiphertextLayout.isWellFormed(ByteArray(28)))
        assertTrue(CiphertextLayout.isWellFormed(ByteArray(64)))
    }
}
