package dev.loginflow.auth.sso

/**
 * Who may exchange the Native SSO entry with this app (A-SECTIPS, A-PERMDEF):
 * only code signed with the same certificate.
 */
internal object SignatureTrust {
    /** A caller of [LoginFlowSsoProvider]: this process, or a same-signer app. */
    fun isTrustedCaller(callerUid: Int, ownUid: Int, isSameSigner: () -> Boolean): Boolean =
        callerUid == ownUid || isSameSigner()

    /**
     * A sibling provider found for an authority: it must exist, belong to
     * another package and be signed with the same certificate.
     */
    fun isTrustedSibling(
        providerPackage: String?,
        ownPackage: String,
        isSameSigner: (String) -> Boolean,
    ): Boolean = providerPackage != null && providerPackage != ownPackage && isSameSigner(providerPackage)
}
