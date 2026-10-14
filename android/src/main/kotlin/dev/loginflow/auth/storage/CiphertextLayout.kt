package dev.loginflow.auth.storage

/** Layout of a stored value: 12-byte GCM IV followed by ciphertext + 16-byte tag. */
internal object CiphertextLayout {
    const val IV_LENGTH = 12
    const val TAG_LENGTH = 16

    /** Shorter input cannot be a value this library wrote; it is refused, not decoded. */
    fun isWellFormed(stored: ByteArray): Boolean = stored.size >= IV_LENGTH + TAG_LENGTH
}
