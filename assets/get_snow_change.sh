#!/bin/bash

set -euo pipefail

# set DEBUG to false, will be evaluated in main()
DEBUG=false

# error output function
err() {
  # date format year-month-day hour:minute:second.millisecond+timezone - requires coreutils date
    printf '%s' "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z') - Error - $1" >&2
}

dbg() {
  # date format year-month-day hour:minute:second.millisecond+timezone - requires coreutils date
  if [[ "$DEBUG" == true ]]; then
    printf '%s' "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z') - Debug - $1" >&2
  fi
}

# check if required apps are installed
check_application_installed() {
    dbg "check_application_installed(): Checking if $1 is installed."

    if [ -x "$(command -v "${1}")" ]; then
      true
    else
      false
    fi
}

token_auth() {
  # parameters username, password, client_id, client_secret, oauth_URL
  # returns bearer token
  # called with: token_auth -O "${oauth_URL}" -u "${username}" -p "${password}" -C "${client_id}" -S "${client_secret}" -o "${timeout}" # optional -g "${grant_type}"
  local OPTIND=1 # reset OPTIND so getopts starts at 1 and parameters are parsed correctly

  local username=""
  local password=""
  local client_id=""
  local client_secret=""
  local oauth_URL=""
  local timeout="60"
  local response=""
  local bearer_token=""
  local grant_type="password" # optional passed parameter, default to password, unlikely to need anything else set

  # parse arguments. use substitution to set grant_type default to 'password'
  while getopts ":u:p:C:S:O:o:g:" arg; do
    case "${arg}" in
      u) username="${OPTARG}" ;;
      p) password="${OPTARG}" ;;
      C) client_id="${OPTARG}" ;;
      S) client_secret="${OPTARG}" ;;
      O) oauth_URL="${OPTARG}" ;;
      o) timeout="${OPTARG}" ;;
      g) grant_type="${OPTARG}" ;;
      *)
        err "Invalid option: -$OPTARG"
        exit 1
        ;;
    esac
  done

  # debug output all passed parameters
  dbg "token_auth(): All passed parameters:"
  dbg " username: $username"
  if [[ "$DEBUG_PASS" == true ]]; then
    dbg " password: $password"
    dbg " client_id: $client_id"
    dbg " client_secret: $client_secret"
  fi
  dbg " oauth_URL: $oauth_URL"
  dbg " timeout: $timeout"
  dbg " grant_type: $grant_type"


  # ensure required parameters are set
  if [[ -z "$username" || -z "$password" || -z "$client_id" || -z "$client_secret" || -z "$oauth_URL" ]]; then
    err "token_auth(): Missing required parameters: username, password, client_id, client_secret, and oauth_URL."
    exit 1
  fi

  # get bearer token
  # save HTTP response code to variable 'code', API response to variable 'body'
  # https://superuser.com/a/1321274
  # ! might need to change this to use printf '%s' instead of echo to avoid issues with escape characters
  dbg "token_auth(): Attempting to authenticate with OAuth."
  response=$(curl -s -k --location -w "\n%{http_code}" -X POST -d "grant_type=$grant_type" -d "username=$username" -d "password=$password" -d "client_id=$client_id" -d "client_secret=$client_secret" "$oauth_URL")
  body=$(echo "$response" | sed '$d')
  code=$(echo "$response" | tail -n1)
  # curl -s -w -k  --location "\n%{http_code}" -X POST -d "grant_type=$grant_type" -d "username=$username" -d "password=$password" -d "client_id=$client_id" -d "client_secret=$client_secret" "$oauth_URL" | {
  #   read -r body
  #   read -r code
  # }

  dbg "token_auth(): HTTP code: $code"
  if [[ -z "$DEBUG_PASS" ]]; then
    dbg "token_auth(): Token auth response: $body"
  fi

  # check if response is 2xx
  if [[ "$code" =~ ^2 ]]; then
    # HTTP 2xx returned, successful API call. get bearer token and clean up
    bearer_token=$(echo "$body" | jq -r '.access_token')
    if [[ -z "$DEBUG_PASS" ]]; then
      dbg "token_auth(): Bearer token: $bearer_token"
    fi
    # return bearer token
    echo "$bearer_token"
  else
    err "Token authentication failed. HTTP response code: $code"
    dbg "Token auth response: $body"
    exit 1
  fi

}

get_chg_detail() {
  # get change ticket details and return JSON object
  # called with: get_chg_detail -u "${username}" -p "${password}" -l "${sn_url}" -c "${change_ticket}" -o "${timeout}" -t "${BEARER_TOKEN}"
  # API Call: GET, https://$sn_url/api/now/table/change_request?sysparm_query=number%3D${change_ticket}
  local OPTIND=1 # reset OPTIND so getopts starts at 1 and parameters are parsed correctly
  local username=""
  local password=""
  local sn_url=""
  local change_ticket=""
  local timeout="60"
  local BEARER_TOKEN=""
  
  # parse arguments
  while getopts ":u:p:l:c:o:t:" arg; do
    case "${arg}" in
      u) username="${OPTARG}" ;;
      p) password="${OPTARG}" ;;
      l) sn_url="${OPTARG}" ;;
      c) change_ticket="${OPTARG}" ;;
      o) timeout="${OPTARG}" ;;
      t) BEARER_TOKEN="${OPTARG}" ;;
      :)
        err "Option -$OPTARG requires an argument."
        exit 1
        ;;
      ?)
        err "Invalid option: -$OPTARG"
        exit 1
        ;;
      *)
        err "Invalid option: -$OPTARG"
        exit 1
        ;;
    esac
  done

  # debug output all passed parameters
  dbg "get_chg_detail(): All passed parameters:"
  dbg " username: $username"
  if [[ "$DEBUG_PASS" == true ]]; then
    dbg " password: $password"
    dbg " BEARER_TOKEN: $BEARER_TOKEN"
  fi
  dbg " sn_url: $sn_url"
  dbg " change_ticket: $change_ticket"
  dbg " timeout: $timeout"

  # validate required parameters
  if [[ -z "$change_ticket" ]]; then
    err "get_chg_detail(): Missing required parameter: change_ticket (-c)"
    exit 1
  fi

  if [[ -z "$sn_url" ]]; then
    err "get_chg_detail(): Missing required parameter: sn_url (-l)"
    exit 1
  fi

  if [[ ( -z "$username" && -z "$password" ) || -z "$BEARER_TOKEN" ]]; then
    err "get_chg_detail(): Missing required parameter(s): either username + password or token."
    exit 1
  fi

  # build URL
  # break up here so we can add logic around pieces of the API call as needed in the future
  local API_ENDPOINT="/api/sn_chg_rest/v1/change"
  local API_QUERY="?sysparm_query=number%3D${change_ticket}"
  local URL="${sn_url}${API_ENDPOINT}${API_QUERY}"

  # get change ticket details
  dbg "get_chg_detail(): Attempting to get change ticket details for: ${change_ticket}"
  # if token is set use that, otherwise use username and password
  # if both are set, use token
  if [[ -n "$BEARER_TOKEN" ]]; then
    dbg "get_chg_detail(): Using token for authentication."
    response=$(curl -k --request GET \
      --connect-timeout "${timeout}" \
      --location \
      --url "${URL}" \
      --header "Authorization: Bearer ${BEARER_TOKEN}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --silent -w "\n%{http_code}")
      # body=$(echo "$response" | sed '$d')
      body=$(printf '%s' "$response" | sed '$d')
      code=$(echo "$response" | tail -n1)
  else
    dbg "get_chg_detail(): Using username and password for authentication."
    response=$(curl -k --request GET \
      --connect-timeout "${timeout}" \
      --location \
      --url "${URL}" \
      --user "${username}:${password}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --silent -w "\n%{http_code}")
      # body=$(echo "$response" | sed '$d')
      body=$(printf '%s' "$response" | sed '$d')
      code=$(echo "$response" | tail -n1)
  fi

  # debug HTTP response code.
  dbg "get_chg_detail(): HTTP code: $code"

  # get JSON response length
  # ! will be 0 if no results are returned from the query (EG: {"result":[]}), or, if there is no value in $body, as in the case of an error
  # response_length=$(echo "$body" | jq -r '.result | length')
  response_length=$(printf '%s' "$body" | jq -r '.result | length')
  dbg "get_chg_detail(): JSON response length: $response_length"

  # check if response is 2xx and response length is greater than 0
  # TODO: clean up comments below
  # TODO: validate the logic and the outputs/errors below for simplicity and clarity
  if [[ "$code" =~ ^2 && $response_length -gt 0 ]]; then
    # HTTP 2xx returned, successful API call. return change ticket details
    # response_length should be 2 for an individual ticket response, .result[0] contains the actual ticket detail, .result[1] contains the query metadata such as original query
    # if multiple tickets are somehow(?) returned, response_length will be greater than 2
    # should be able to address the change number with .result[].number (though this also returns 'null' for other index values in .result[] array), or specifically .result[0].number
    # check if response is expected JSON
    # if so, return .result[0] which contains the ticket details
    # if echo "$body" | jq 'has("result")' > /dev/null 2>&1; then
    if printf '%s' "$body" | jq 'has("result")' > /dev/null 2>&1; then
      dbg "get_chg_detail(): JSON is expected response body."
      dbg "get_chg_detail(): Change ticket raw response: $body"
      printf '%s' "$body" | jq '.result[0]' -c
    fi

  elif [[ "$code" =~ ^2 && $response_length -eq 0 ]]; then
    # this condition should be met on a successful API hit but no tickets returned
    dbg "get_chg_detail(): JSON response length: $response_length"
    err "get_chg_detail(): No results returned for change ticket: ${change_ticket}"
    exit 1
  else
    # HTTP response code is not 2xx, return error
    # on bad auth for example, there should still be a JSON response, but it will be an error message
    # return 
    err "get_chg_detail(): Failed to get change ticket details from API. HTTP response code: $code"
    err "get_chg_detail(): API response: $body"
    exit 1
  fi

}

main() {
  # incoming parameters
  dbg "main(): All passed parameters (\$*): $*"

  local sn_url=""
  local username=""
  local password=""
  local timeout="60" # default timeout value
  local oauth_endpoint="oauth_token.do"
  local client_id=""
  local client_secret=""
  local BEARER_TOKEN=""
  local change_ticket=""
  local change_ticket_detail=""
  DEBUG=false
  DEBUG_PASS=false

  # parse arguments
  while getopts ":u:p:c:C:S:l:o:D:P" arg; do
    case "${arg}" in
      u) username="${OPTARG}" ;;
      p) password="${OPTARG}" ;;
      C) client_id="${OPTARG}" ;;
      S) client_secret="${OPTARG}" ;;
      l) sn_url="${OPTARG}" ;;
      o) timeout="${OPTARG}" ;;
      D) DEBUG="$OPTARG" ;;
      P) DEBUG_PASS=true ;;
      c) change_ticket="${OPTARG}" ;;
      :) err "Option -$OPTARG requires an argument."; exit 1 ;;
      ?) err "Invalid option: -$OPTARG"; exit 1 ;;
      *) err "Invalid option: -$OPTARG"; exit 1 ;;
    esac
  done

  # set DEBUG and DEBUG_PASS as environment variables
  export DEBUG
  export DEBUG_PASS

  # debug output all passed parameters
    dbg "main(): All passed parameters:"
    dbg " sn_url: $sn_url"
    dbg " username: $username"
    if [[ "$DEBUG_PASS" == true ]]; then
      dbg " password: $password"
      dbg " client_id: $client_id"
      dbg " client_secret: $client_secret"
    fi
    dbg " change_ticket: $change_ticket"
    dbg " timeout: $timeout"
    dbg " DEBUG: $DEBUG"
    dbg " DEBUG_PASS: $DEBUG_PASS"

  # check for required parameters
  if [[ -z "$change_ticket" || -z "$sn_url" || ( -z "$username" && -z "$password" ) || ( -z "$username" && -z "$password" && -z "$client_id" && -z "$client_secret" ) ]]; then
    err "main(): Missing required parameters: change_ticket, sn_url, and either Username and Password, or Username + Password + Client ID + Client Secret."
    exit 1
  fi

  # VALIDATION STEPS
  # check if jq and curl are installed
  if ! check_application_installed jq; then
    err "jq not available, aborting."
    exit 1
  else
    dbg "main(): jq version: $(jq --version)"
  fi

  if ! check_application_installed curl; then
    err "curl not available, aborting."
    exit 1
  else
    dbg "main(): curl version: $(curl --version | head -n 1)"
  fi
  # validate CHG ticket format
  if [[ "${change_ticket}" != CHG* ]]; then
    err "main(): Invalid Change Ticket format. Must start with 'CHG'.";
    exit 1;
  fi


  # normalize sn_url. remove trailing slash if present
  sn_url=$(echo "$sn_url" | sed 's/\/$//')

  # test if url is valid and reachable
  if ! curl -Lk -s -w "%{http_code}" "$sn_url" -o /dev/null | grep "200" > /dev/null; then
    err "main(): Invalid or unreachable URL: $sn_url"
    exit 1
  fi

  # if user, pass, client_id, and client_secret are set, build oauth URL and authenticate
  if [[ -n "$username" && -n "$password" && -n "$client_id" && -n "$client_secret" ]]; then
    oauth_URL="${sn_url}/${oauth_endpoint}"
    dbg "main(): Using OAuth for authentication: ${oauth_URL}"
    BEARER_TOKEN=$(token_auth -O "${oauth_URL}" -u "${username}" -p "${password}" -C "${client_id}" -S "${client_secret}" -o "${timeout}")
    if [[ "$DEBUG_PASS" == true ]]; then
      dbg "main(): BEARER_TOKEN: $BEARER_TOKEN"
    fi
  fi

  # get change ticket details
  change_ticket_detail=$(get_chg_detail -u "${username}" -p "${password}" -l "${sn_url}" -c "${change_ticket}" -o "${timeout}" -t "${BEARER_TOKEN}")

  printf '%s' "$change_ticket_detail"
}

main "$@"