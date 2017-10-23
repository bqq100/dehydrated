#!/bin/sh

# The deploy_cert and unchanged_cert arguments are different when a PFX certificate is generated.  
# In the case of an insecure PFX certificate, the PWDFILE argument is empty

deploy_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}" CONTACT_EMAIL="${4}"

    # This hook is called once for every domain that needs to be
    # validated, including any alternative names you may have listed.
    # If HOOK_CHAIN is set to yes, all sub-domain challenges are
    # called at the same time.  This means instead of 4 arguments
    # there will 4*[# of domains] arguments
    #
    # Parameters:
    # - DOMAIN
    #   The domain name (CN or subject alternative name) being
    #   validated.
    # - TOKEN_FILENAME
    #   The name of the file containing the token to be served for HTTP
    #   validation. Should be served by your web server as
    #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
    # - TOKEN_VALUE
    #   The token value that needs to be served for validation. For DNS
    #   validation, this is what you want to put in the _acme-challenge
    #   TXT record. For HTTP validation it is the value that is expected
    #   be found in the $TOKEN_FILENAME file.
    # - CONTACT_EMAIL
    #   The email address to send certificate related emails to
}

clean_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}" CONTACT_EMAIL="${4}"

    # This hook is called after attempting to validate each domain,
    # whether or not validation was successful. Here you can delete
    # files or DNS records that are no longer needed.
    #
    # The parameters are the same as for deploy_challenge.
}

deploy_cert() {
    local DOMAIN="${1}" PWDFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}" CONTACT_EMAIL="${7}"

    # This hook is called once for each certificate that has been
    # produced. Here you might, for instance, copy your new certificates
    # to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - PWDFILE
    #   The path of the file containing the password to the pfx certificate. This will be empty for insecure pfx certificates.
    # - CERTFILE
    #   The path of the file containing the pfx certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - TIMESTAMP
    #   Timestamp when the specified certificate was created.
    # - CONTACT_EMAIL
    #   The email address to send certificate related emails to
}

unchanged_cert() {
    local DOMAIN="${1}" PWDFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" CONTACT_EMAIL="${6}"

    # This hook is called once for each certificate that is still
    # valid and therefore wasn't reissued.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - PWDFILE
    #   The path of the file containing the password to the pfx certificate. This will be empty for insecure pfx certificates.
    # - CERTFILE
    #   The path of the file containing the pfx certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - CONTACT_EMAIL
    #   The email address to send certificate related emails to
}

HANDLER="$1"; shift
"$HANDLER" "$@"
