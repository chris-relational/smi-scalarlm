#!/usr/bin/env bash

# U s a g e
# Overide the contents of infra/cray_infra/util/default_config.py either using options with the same name or 
# environment variables e.g.
# $ bash scripts/server.sh --model meta-llama/Llama-3.2-1B-Instruct --response_timeout 1200 --max_model_length 1024

# If an option is missing the script tries to get it from the related env var:
# SMI_MODEL for model
# SMI_RESPONSE_TIMEOUT for response_timeout
# SMI_MAX_TOKEN_LENGTH for max_token_length


# P r e p a r a t i o n s
# Safely execute this bash script
# e exit on first failure
# x all executed commands are printed to the terminal
# E any trap on ERR is inherited by shell functions
# "-o pipefail" produces a failure code if any stage fails

# The following are not set
# a export all variables to the environment
# u unset variables are errors
set -Eeox pipefail


# A r g u m e n t   P a r s i n g
opts=$(echo "$@" | sed -e "s/=/ /g")
set -e -- $opts

function ensure() {
    # For options taking >1 values, ensure they're available in the input
    # Example usage: "ensure $@ 3"
    nargs=$1; shift 1
    if [[ $# -lt $nargs ]]; then
        echo "$nargs arguments required in option, $# given. Exiting."
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model)
            shift 
            model="$1"
            ;;
        -l|--max_model_length)
            shift 
            max_model_length="$1";
            ;;
        -t|--response_timeout)
            shift 
            response_timeout="$1"
            ;;
        *)
            shift 
            ;;
    esac
done

config_dir=$(realpath ${BASH_SOURCE[0]})
config_dir=${config_dir%/scripts/serve.sh}

tmp_config_path=$config_dir/cray-config.tmp
>$tmp_config_path

[[ -n ${model:=$SMI_MODEL} ]] && echo "model: $model" >>$tmp_config_path
[[ -n ${max_model_length:=$SMI_MAX_MODEL_LENGTH} ]] && echo "max_model_length: $max_model_length" >>$tmp_config_path
[[ -n ${response_timeout:=$SMI_RESPONSE_TINEOUT} ]] && echo "response_timeout: $response_timeout" >>$tmp_config_path

[[ $(wc -l <$tmp_config_path) -gt 0 ]] && mv -f $tmp_config_path $config_dir/cray-config.yaml

# Get the directory of this script
LOCAL_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
$LOCAL_DIRECTORY/start_slurm.sh
python -m cray_infra.one_server.main
