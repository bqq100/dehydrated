#!/usr/bin/env bash

# SMTP Server Settings
SMTP_SERVER="localhost"
SMTP_PORT=25

# Cloudflare API Credentials
ZONE_ID="your_zone_id"
API_KEY="your_api_key"
EMAIL="your_email"

function deploy_challenge {
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

    process_challenge "DEPLOY" $@
}

function clean_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}" CONTACT_EMAIL="${4}"

    # This hook is called after attempting to validate each domain,
    # whether or not validation was successful. Here you can delete
    # files or DNS records that are no longer needed.
    #
    # The parameters are the same as for deploy_challenge.

    process_challenge "CLEAN" $@
}

sync_cert() {
    local KEYFILE="${1}" CERTFILE="${2}" FULLCHAINFILE="${3}" CHAINFILE="${4}" REQUESTFILE="${5}"

    # This hook is called after the certificates have been created but before
    # they are symlinked. This allows you to sync the files to disk to prevent
    # creating a symlink to empty files on unexpected system crashes.
    #
    # This hook is not intended to be used for further processing of certificate
    # files, see deploy_cert for that.
    #
    # Parameters:
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - REQUESTFILE
    #   The path of the file containing the certificate signing request.

    # Simple example: sync the files before symlinking them
    # sync "${KEYFILE}" "${CERTFILE} "${FULLCHAINFILE}" "${CHAINFILE}" "${REQUESTFILE}"
}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}" CONTACT_EMAIL="${7}"

    # This hook is called once for each certificate that has been
    # produced. Here you might, for instance, copy your new certificates
    # to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - TIMESTAMP
    #   Timestamp when the specified certificate was created.
    # - CONTACT_EMAIL
    #   The email address to send certificate related emails to

    # send email notification
    send_notification $CONTACT_EMAIL $DOMAIN

    PIDS=$(ps -ef | grep -v start-dehydrated | grep -o "^\w*\s\s*[0-9][0-9]*\s\s*1\s" | grep -o "\s\s*[0-9][0-9]*\s\s*" | grep -o [0-9][0-9]*)
    /bin/bash -c "sleep 600 && echo 'Killing docker container due to certificate refresh' && kill -KILL ${PIDS}" &

}

# TODO: Add support for CONTACT_EMAIL
deploy_ocsp() {
    local DOMAIN="${1}" OCSPFILE="${2}" TIMESTAMP="${3}"

    # This hook is called once for each updated ocsp stapling file that has
    # been produced. Here you might, for instance, copy your new ocsp stapling
    # files to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - OCSPFILE
    #   The path of the ocsp stapling file
    # - TIMESTAMP
    #   Timestamp when the specified ocsp stapling file was created.

    # Simple example: Copy file to nginx config
    # cp "${OCSPFILE}" /etc/nginx/ssl/; chown -R nginx: /etc/nginx/ssl
    # systemctl reload nginx
}

function unchanged_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" CONTACT_EMAIL="${6}"

    # This hook is called once for each certificate that is still
    # valid and therefore wasn't reissued.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - CONTACT_EMAIL
    #   The email address to send certificate related emails to
}

invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"

    # This hook is called if the challenge response has failed, so domain
    # owners can be aware and act accordingly.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - RESPONSE
    #   The response that the verification server returned

    # Simple example: Send mail to root
    # printf "Subject: Validation of ${DOMAIN} failed!\n\nOh noez!" | sendmail root
}

request_failure() {
    local STATUSCODE="${1}" REASON="${2}" REQTYPE="${3}" HEADERS="${4}"

    # This hook is called when an HTTP request fails (e.g., when the ACME
    # server is busy, returns an error, etc). It will be called upon any
    # response code that does not start with '2'. Useful to alert admins
    # about problems with requests.
    #
    # Parameters:
    # - STATUSCODE
    #   The HTML status code that originated the error.
    # - REASON
    #   The specified reason for the error.
    # - REQTYPE
    #   The kind of request that was made (GET, POST...)
    # - HEADERS
    #   HTTP headers returned by the CA

    # Simple example: Send mail to root
    # printf "Subject: HTTP request failed failed!\n\nA http request failed with status ${STATUSCODE}!" | sendmail root
}

generate_csr() {
    local DOMAIN="${1}" CERTDIR="${2}" ALTNAMES="${3}"

    # This hook is called before any certificate signing operation takes place.
    # It can be used to generate or fetch a certificate signing request with external
    # tools.
    # The output should be just the cerificate signing request formatted as PEM.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain as specified in domains.txt. This does not need to
    #   match with the domains in the CSR, it's basically just the directory name.
    # - CERTDIR
    #   Certificate output directory for this particular certificate. Can be used
    #   for storing additional files.
    # - ALTNAMES
    #   All domain names for the current certificate as specified in domains.txt.
    #   Again, this doesn't need to match with the CSR, it's just there for convenience.

    # Simple example: Look for pre-generated CSRs
    # if [ -e "${CERTDIR}/pre-generated.csr" ]; then
    #   cat "${CERTDIR}/pre-generated.csr"
    # fi
}

startup_hook() {
  # This hook is called before the cron command to do some initial tasks
  # (e.g. starting a webserver).

  :
}

exit_hook() {
  local ERROR="${1:-}"

  # This hook is called at the end of the cron command and can be used to
  # do some final (cleanup or other) tasks.
  #
  # Parameters:
  # - ERROR
  #   Contains error message if dehydrated exits with error
}

function send_notification {
    local SENDER="${1}" RECIPIENT="${1}" DOMAIN="${2}" TODAYS_DATE=`date` HOST_NAME=`hostname`

    # send notification email
    cat << EOF | /usr/bin/nc ${SMTP_SERVER} ${SMTP_PORT}
MAIL FROM:$SENDER
RCPT TO:$RECIPIENT
DATA
Content-Type:text/html;charset='UTF-8'
Content-Transfer-Encoding:7bit
From:SSL Certificate Renewal Script<$SENDER>
To:<$RECIPIENT>
Subject: New Certificate Deployed - $TODAYS_DATE

<html>
<p style="font-size: 1em; color: black;">A new certificate for the domain <b>${DOMAIN}</b> has been deployed.</p>
<p style="font-size: 1em; color: black;">Please confirm certificate is working as expected.</p>
<br>
<p style="font-size: 1em; color: black;">This certificate was deployed from <b>${HOST_NAME}</b>.</p>
</html>
.
quit
EOF

}

function process_challenge {
    local TYPE="${1}"; shift

    local FIRSTDOMAIN="${1}"
    local SLD=`sed -E 's/(.*\.)*([^.]+)\..*/\2/' <<< "${FIRSTDOMAIN}"`
    local TLD=`sed -E 's/.*\.([^.]+)/\1/' <<< "${FIRSTDOMAIN}"`

    local API_ENDPOINT="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
    local POSTDATA=""

    local num=1

    # get list of current records for domain
    local records_list=`/usr/bin/curl -s -X GET "$API_ENDPOINT" \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json" | jq -r '.result[] | @base64'`

    # remove challenge records from list
    # This only really matters for $TYPE == "CLEAN"
    if [ "$TYPE" == "CLEAN" ]; then
        records_list=`echo "$records_list" | base64 --decode | jq -r 'select(.name | contains("acme-challenge") | not)' | jq -r @base64`
    fi

    # parse and store current records
    OLDIFS=$IFS
    for record in $records_list; do
        current_record=`echo $record | base64 --decode`
        record_id=`echo $current_record | jq -r '.id'`
        record_name=`echo $current_record | jq -r '.name'`
        record_type=`echo $current_record | jq -r '.type'`
        record_content=`echo $current_record | jq -r '.content'`
        record_ttl=`echo $current_record | jq -r '.ttl'`

        POSTDATA=$POSTDATA" --data-urlencode 'id$num=$record_id'"
        POSTDATA=$POSTDATA" --data-urlencode 'name$num=$record_name'"
        POSTDATA=$POSTDATA" --data-urlencode 'type$num=$record_type'"
        POSTDATA=$POSTDATA" --data-urlencode 'content$num=$record_content'"
        POSTDATA=$POSTDATA" --data-urlencode 'ttl$num=$record_ttl'"

        ((num++))
    done
    IFS=$OLDIFS

    local items=0

    if [ "$TYPE" == "DEPLOY" ]; then

        # add challenge records to post data
        local count=0
        while (( "$#" >= 4 )); do
            DOMAIN="${1}"; shift
            TOKEN_FILENAME="${1}"; shift
            TOKEN_VALUE[$count]="${1}"; shift
            CONTACT_EMAIL="${1}"; shift

            SUB[$count]=`sed -E "s/.$SLD.$TLD//" <<< "${DOMAIN}"`

            POSTDATA=$POSTDATA" --data-urlencode 'name$num=_acme-challenge.${SUB[$count]}.$SLD.$TLD'"
            POSTDATA=$POSTDATA" --data-urlencode 'type$num=TXT'"
            POSTDATA=$POSTDATA" --data-urlencode 'content$num=${TOKEN_VALUE[$count]}'"
            POSTDATA=$POSTDATA" --data-urlencode 'ttl$num=60'"

            ((num++))
            ((count++))
        done

        items=$count

    fi

    local command="/usr/bin/curl -sv -X POST $API_ENDPOINT \
        -H 'X-Auth-Email: $EMAIL' \
        -H 'X-Auth-Key: $API_KEY' \
        -H 'Content-Type: application/json' \
        --data '$POSTDATA' 2>&1 > /dev/null"
    eval $command

    if [ "$TYPE" == "DEPLOY" ]; then

        # wait up to 30 minutes for DNS updates to be provisioned (check at 15 second intervals)
        timer=0
        count=0
        while [ $count -lt $items ]; do
            until dig @8.8.8.8 txt "_acme-challenge.${SUB[$count]}.$SLD.$TLD" | grep -- "${TOKEN_VALUE[$count]}" 2>&1 > /dev/null; do
                if [[ "$timer" -ge 1800 ]]; then
                    # time has exceeded 30 minutes
                    break
                else
                    echo " + DNS not propagated. Waiting 15s for record creation and replication... Total time elapsed has been $timer seconds."
                    ((timer+=15))
                    sleep 15
                fi
            done
            ((count++))
        done
    fi
}


HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|sync_cert|deploy_cert|deploy_ocsp|unchanged_cert|invalid_challenge|request_failure|generate_csr|startup_hook|exit_hook)$ ]]; then
  "$HANDLER" "$@"
fi

exit 0
