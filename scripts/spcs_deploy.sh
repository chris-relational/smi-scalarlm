#!/usr/bin/env bash

# U s a g e
# The script 

# e exit on first failure
# x all executed commands are printed to the terminal
# u unset variables are errors
# a export all variables to the environment
# E any trap on ERR is inherited by shell functions
# -o pipefail | produces a failure code if any stage fails
set -Eeuoxa pipefail

# image name and tag: {repo}-{commit}:{target}-{tag}

account_id='ndsoebe-rai_prod_gen_ai_aws_us_west_2_consumer'
user='chris_malliopoulos'
password='Wednesd@y19Feb2025'

# Docker image path-name-tag
# {account_id}.registry.snowflakecomputing.com/{database}/{schema}/{repository}/{git_repo}-{git_commit}:{target}-{tag}
database='scalarlm_spcs_db' 
schema='scalarlm_spcs_schema' 
repository='scalarlm_spcs_repository'
git_repo=smi-scalarlm 
git_commit=latest 

# NB! this won't build in arm64 architectures (QEMU virtualization doesn't work for vLLM)
platform="linux/amd64"
tag="x86"
target=cpu


# E n s u r e  S F  C o n n e c t i o n
snow sql -q 'select 1;' >/dev/null && echo "Connection to SF: OK" || ( echo "Could not connect to SF. Exiting"; exit 1 )

# Login to SPCS
echo ${password} | docker login -u ${user} --password-stdin ${account_id}.registry.snowflakecomputing.com


# B u i l d  t h e  I m a g e
docker build \
    --platform ${platform} \
    --build-arg BASE_NAME=${target} \
    --build-arg VLLM_TARGET_DEVICE=${target} \
    -f cpu.dockerfile \
    -t ${account_id}.registry.snowflakecomputing.com/${database}/${schema}/${repository}/${git_repo}-${git_commit}:${target}-${tag} \
    --shm-size=8g .


# P u s h  t o  S n o w f l a k e
# Prerequisites
# snowsql> ALTER USER <user name> SET mins_to_bypass_mfa = 1440;
# docker login wcwhvmh-fmb70117.registry.snowflakecomputing.com -u <user name> -p <password>
echo "Pushing to SPCS"
docker push ${account_id}.registry.snowflakecomputing.com/${database}/${schema}/${repository}/${git_repo}-${git_commit}:${target}-${tag}

