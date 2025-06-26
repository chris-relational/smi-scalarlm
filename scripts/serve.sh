#!/usr/bin/env bash

# Usage
# Option 1: $ MODEL_ID=<model-id> serve.sh 
# Option 2: serve.sh <model-id>
# <model-id> is a Huggingface model

echo "model: ${SCALARLM_MODEL_ID:=$1}" >cray-config.yaml

scripts/start_slurm.sh
python -m cray_infra.one_server.main
