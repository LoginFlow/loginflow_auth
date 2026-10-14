package dev.loginflow.auth.storage

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import java.security.GeneralSecurityException

/**
 * Private SharedPreferences whose values are encrypted with [KeystoreCipher].
 *
 * A value that no longer decrypts (for example restored from a backup onto
 * a device whose Keystore never had the key) is deleted and reported as
 * absent, so the user simply signs in again.
 */
internal class EncryptedPreferences private constructor(context: Context, name: String) {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(name, Context.MODE_PRIVATE)
    private val cipher = KeystoreCipher("$name.key.v1")

    @Synchronized
    fun get(entry: String): String? {
        val stored = preferences.getString(entry, null) ?: return null
        return try {
            val ciphertext = Base64.decode(stored, Base64.NO_WRAP)
            String(cipher.decrypt(ciphertext, entry), Charsets.UTF_8)
        } catch (error: GeneralSecurityException) {
            Log.w(TAG, "Discarding an entry that no longer decrypts: ${error.javaClass.simpleName}")
            preferences.edit().remove(entry).commit()
            null
        } catch (error: IllegalArgumentException) {
            Log.w(TAG, "Discarding a corrupt entry.")
            preferences.edit().remove(entry).commit()
            null
        }
    }

    @Synchronized
    fun put(entry: String, value: String) {
        val ciphertext = cipher.encrypt(value.toByteArray(Charsets.UTF_8), entry)
        val isSaved = preferences.edit()
            .putString(entry, Base64.encodeToString(ciphertext, Base64.NO_WRAP))
            .commit()
        if (!isSaved) {
            throw GeneralSecurityException("Could not persist the encrypted entry.")
        }
    }

    @Synchronized
    fun remove(entry: String) {
        preferences.edit().remove(entry).commit()
    }

    companion object {
        private const val TAG = "LoginFlowAuth"
        private val instances = HashMap<String, EncryptedPreferences>()

        /**
         * One instance per preferences file, shared by the plugin's worker
         * thread and the provider's binder threads, so key generation and
         * writes never race.
         */
        fun named(context: Context, name: String): EncryptedPreferences = synchronized(instances) {
            instances.getOrPut(name) { EncryptedPreferences(context.applicationContext, name) }
        }
    }
}
