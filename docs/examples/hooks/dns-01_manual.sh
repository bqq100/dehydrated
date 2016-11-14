#!/usr/bin/env bash

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

    # restart Apache
    echo " + Reloading Apache configuration"
    systemctl reload httpd.service

    # send email notification
    send_notification $CONTACT_EMAIL $DOMAIN
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

function send_notification {
    local SENDER="${1}" RECIPIENT="${1}" DOMAIN="${2}" TODAYS_DATE=`date`

    # send notification email
    cat << EOF | /usr/sbin/sendmail -t -f $SENDER
Content-Type:text/html;charset='UTF-8'
Content-Transfer-Encoding:7bit
From:SSL Certificate Renewal Script<$SENDER>
To:<$RECIPIENT>
Subject: New Certificate Deployed - $TODAYS_DATE

<html>
<p style="font-size: 1em; color: black;">A new certificate for the domain <b>${DOMAIN}</b> has been deployed.</p>
<p style="font-size: 1em; color: black;">Please confirm certificate is working as expected.</p>
</html>
EOF
}

function challenge_notify {
    local SENDER="${1}" RECIPIENT="${1}" TYPE="$2" DOMAIN="${3}" DATA="${4}" TODAYS_DATE=`date`

    local SUBJECT="ACTION NEEDED: Domain Verification for ${DOMAIN} Complete - Cleanup Required"
    local BODY="The certificate for domain <b>${DOMAIN}</b> is being renewed.  Domain verification has been completed, please remove the following DNS records."

    if [ "${TYPE}" == "DEPLOY" ]; then
        SUBJECT="ACTION NEEDED: Domain Verification for ${DOMAIN} Required"
        BODY="The certificate for domain <b>${DOMAIN}</b> is about to expire.  In order to issue a new certificate, please setup the following DNS records within the next 24 hours."
    fi

    #Apply CSS styling
    DATA=$(echo "${DATA}" | sed 's/<table>/<table style="border: 3px solid black; border-collapse: collapse;">/g')
    DATA=$(echo "${DATA}" | sed 's/<td>/<td style="padding-bottom: 10px; padding-left: 10px; padding-right:10px; font-size: 1em; color: black;">/g')
    DATA=$(echo "${DATA}" | sed 's/<th>/<th style="padding: 10px; border-top: 3px solid black; font-weight: normal; font-size: 1em; color: black; text-align: left;">/g')
    DATA=$(echo "${DATA}" | sed 's/<span>/<span style="font-weight: bold; font-size: 1.2em; color: black;">/g')

    # send notification email
    cat << EOF | /usr/sbin/sendmail -t -f $SENDER
Content-Type:text/html;charset='UTF-8'
Content-Transfer-Encoding:7bit
From:SSL Certificate Renewal Script<$SENDER>
To:<$RECIPIENT>
Subject: ${SUBJECT}

<html>
<p style="font-size: 1em; color: black;">${BODY}</p>
${DATA}
</html>
EOF
}

function process_challenge {
    local TYPE="${1}"; shift

    local FIRSTDOMAIN="${1}"
    local CONTACT_EMAIL="${4}"
    local SLD=`sed -E 's/(.*\.)*([^.]+)\..*/\2/' <<< "${FIRSTDOMAIN}"`
    local TLD=`sed -E 's/.*\.([^.]+)/\1/' <<< "${FIRSTDOMAIN}"`

    local DATA=""

    # add challenge records to post data
    local count=0

    while (( "$#" >= 3 )); do
        # DOMAIN
        #   The domain name (CN or subject alternative name) being validated.
        DOMAIN="${1}"; shift
        # TOKEN_FILENAME
        #   The name of the file containing the token to be served for HTTP
        #   validation. Should be served by your web server as
        #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
        TOKEN_FILENAME="${1}"; shift
        # TOKEN_VALUE
        #   The token value that needs to be served for validation. For DNS
        #   validation, this is what you want to put in the _acme-challenge
        #   TXT record. For HTTP validation it is the value that is expected
        #   be found in the $TOKEN_FILENAME file.
        TOKEN_VALUE[$count]="${1}"; shift
        # CONTACT_EMAIL
        #   The email address to send certificate related emails to
        CONTACT_EMAIL="${1}"; shift

        SUB[$count]=`sed -E "s/.$SLD.$TLD//" <<< "${DOMAIN}"`

        DATA=$DATA"<tr><th><span>Domain</span></th><th>$SLD.$TLD</th></tr>"
        DATA=$DATA"<tr><td><span>Hostname</span></td><td>_acme-challenge.${SUB[$count]}</td></tr>"
        DATA=$DATA"<tr><td><span>RecordType</span></td><td>TXT</td></tr>"

        if [ "$TYPE" == "DEPLOY" ]; then
            DATA=$DATA"<tr><td><span>Value</span></td><td>${TOKEN_VALUE[$count]}</td></tr>"
            DATA=$DATA"<tr><td><span>TTL</span></td><td>1&nbsp;min</td></tr>"
        fi

        ((count++))
    done

    DATA="<p><table>$DATA</table></p>"

    challenge_notify $CONTACT_EMAIL $TYPE $FIRSTDOMAIN $DATA

    local items=$count

    if [ "$TYPE" == "DEPLOY" ]; then

        # wait up to 24 hours for DNS updates to be provisioned (check at 5 min intervals)
        timer=0
        count=0
        while [ $count -lt $items ]; do
            until dig @8.8.8.8 txt "_acme-challenge.${SUB[$count]}.$SLD.$TLD" | grep "${TOKEN_VALUE[$count]}" 2>&1 > /dev/null; do
                if [[ "$timer" -ge 86400 ]]; then
                    # time has exceeded 24 hours
                    break
                else
                    echo " + DNS not propagated. Waiting 5min for record creation and replication... Total time elapsed has been $timer seconds."
                    ((timer+=300))
                    sleep 300
                fi
            done
            ((count++))
        done
    fi
}

HANDLER=$1; shift; $HANDLER $@
exit 0
