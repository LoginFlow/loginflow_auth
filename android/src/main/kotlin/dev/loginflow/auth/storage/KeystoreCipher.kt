package dev.loginflow.auth.storage

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.InvalidKeyException
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * AES-256-GCM with a non-exportable key held by the Android Keystore
 * (A-KEYSTORE "Extraction prevention"). The entry name is bound as
 * additional authenticated data, so a ciphertext cannot be moved to another
 * entry.
 */
internal class KeystoreCipher(private val alias: String) {
    private val keyStore: KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    /**
     * Encrypts with the current key. A key the system invalidated (for
     * example after a lock-screen change, `KeyPermanentlyInvalidatedException`)
     * is deleted and regenerated once, so later writes keep working; values
     * written with the old key no longer decrypt and are discarded on read.
     */
    fun encrypt(plaintext: ByteArray, entry: String): ByteArray = try {
        encryptWith(key(), plaintext, entry)
    } catch (invalidated: InvalidKeyException) {
        keyStore.deleteEntry(alias)
        encryptWith(generateKey(), plaintext, entry)
    }

    private fun encryptWith(key: SecretKey, plaintext: ByteArray, entry: String): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD(entry.toByteArray(Charsets.UTF_8))
        return cipher.iv + cipher.doFinal(plaintext)
    }

    fun decrypt(ciphertext: ByteArray, entry: String): ByteArray {
        if (!CiphertextLayout.isWellFormed(ciphertext)) {
            throw AEADBadTagException("Stored value is shorter than IV + tag.")
        }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        val iv = ciphertext.copyOfRange(0, IV_LENGTH)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_LENGTH_BITS, iv))
        cipher.updateAAD(entry.toByteArray(Charsets.UTF_8))
        return cipher.doFinal(ciphertext, IV_LENGTH, ciphertext.size - IV_LENGTH)
    }

    private fun key(): SecretKey =
        (keyStore.getKey(alias, null) as? SecretKey) ?: generateKey()

    private fun generateKey(): SecretKey {
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(KEY_SIZE_BITS)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH = CiphertextLayout.IV_LENGTH
        const val TAG_LENGTH_BITS = CiphertextLayout.TAG_LENGTH * 8
        const val KEY_SIZE_BITS = 256
    }
}
