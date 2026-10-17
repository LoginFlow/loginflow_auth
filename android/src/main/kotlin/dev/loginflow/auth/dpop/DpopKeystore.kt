package dev.loginflow.auth.dpop

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Base64
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PublicKey
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec

/**
 * A non-exportable ES256 (P-256) signing key per `alias`, held by the Android
 * Keystore. `setIsStrongBoxBacked(true)` is attempted first (hardware
 * security module, A-KEYSTORE); on a device without one
 * (`StrongBoxUnavailableException`) the key is regenerated in the regular
 * Keystore, which is still non-exportable. The private key never leaves the
 * Keystore: only the public key and signatures cross the method channel.
 */
internal class DpopKeystore(private val alias: String) {
    private val keyStore: KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    /** The key's public JWK (`alg: "ES256"`), generating it the first time. */
    fun ensurePublicJwk(): Map<String, Any?> {
        val publicKey = publicKey() ?: generateKeyPair().public
        return jwkOf(publicKey as ECPublicKey)
    }

    /** Raw `R || S` (64 bytes) over [signingInput], base64url without padding. */
    fun sign(signingInput: ByteArray): String {
        val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
            ?: generateKeyPair().let { keyStore.getEntry(alias, null) as KeyStore.PrivateKeyEntry }
        val signature = Signature.getInstance("SHA256withECDSA").apply {
            initSign(entry.privateKey)
            update(signingInput)
        }
        return derToRawSignature(signature.sign()).toBase64Url()
    }

    private fun publicKey(): PublicKey? =
        keyStore.getCertificate(alias)?.publicKey

    private fun generateKeyPair(): java.security.KeyPair {
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
        return try {
            generator.initialize(spec.setIsStrongBoxBacked(true).build())
            generator.generateKeyPair()
        } catch (unavailable: StrongBoxUnavailableException) {
            generator.initialize(spec.setIsStrongBoxBacked(false).build())
            generator.generateKeyPair()
        }
    }

    private fun jwkOf(publicKey: ECPublicKey): Map<String, Any?> {
        val fieldSize = (publicKey.params.curve.field.fieldSize + 7) / 8
        val x = publicKey.w.affineX.toFixedLengthByteArray(fieldSize)
        val y = publicKey.w.affineY.toFixedLengthByteArray(fieldSize)
        return mapOf(
            "kty" to "EC",
            "crv" to "P-256",
            "x" to x.toBase64Url(),
            "y" to y.toBase64Url(),
        )
    }

    /**
     * `SHA256withECDSA` signs ASN.1 DER (`SEQUENCE { INTEGER r, INTEGER s }`);
     * RFC 7518 §3.4 wants the raw, fixed-length `R || S` instead. Parsed by
     * hand: a two-field DER structure does not need a parser dependency.
     */
    private fun derToRawSignature(der: ByteArray): ByteArray {
        var offset = 2 // SEQUENCE tag + length
        fun readInt(): ByteArray {
            offset += 1 // INTEGER tag
            val length = der[offset].toInt() and 0xFF
            offset += 1
            val bytes = der.copyOfRange(offset, offset + length)
            offset += length
            return bytes
        }
        val r = readInt().stripLeadingZero().toFixedLengthByteArray(32)
        val s = readInt().stripLeadingZero().toFixedLengthByteArray(32)
        return r + s
    }

    private fun ByteArray.stripLeadingZero(): ByteArray =
        if (size > 1 && this[0] == 0.toByte()) copyOfRange(1, size) else this

    private fun ByteArray.toFixedLengthByteArray(length: Int): ByteArray {
        if (size == length) return this
        val padded = ByteArray(length)
        val offset = length - size
        System.arraycopy(this, 0, padded, offset, size)
        return padded
    }

    private fun java.math.BigInteger.toFixedLengthByteArray(length: Int): ByteArray =
        toByteArray().stripLeadingZero().toFixedLengthByteArray(length)

    private fun ByteArray.toBase64Url(): String =
        Base64.encodeToString(this, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
    }
}
