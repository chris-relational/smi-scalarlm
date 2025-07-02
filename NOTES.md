# Table of Contents

[Repository forking and cloning](#repository-forking-and-cloning)  

[`runpod.io` Experiments](#runpodio-experiments)  

[Local Experiments](#local-experiments)  

[Local Cleanup Scripts](#local-cleanup-scripts)  


# Repository forking and cloning
`supermassive-intelligence/scalarlm` is forked to `chris-relational/smi-scalarlm` and the latter is cloned locally


# Files and Folders added
1. This file is added to the project folder.
2. `var` folder contains developent artifacts not pushed to the repo.  

3. `smi-scalarlm/cpu.dockerfile` contains the cpu docker build script (this can be the exactly the same as `Dockerfile@main`, 
   or a stripped version of it or sth substantially different). 
   The purpose is to use this file for local building of the cpu image. The same imageis expected to run on SPCS.
4. `spcs` folder contains the source code wrappers — again this may be empty or contain uvicorn wrappers or new endpoints and a different uvicorn app.
5. Shell scripts (possible wrappers around the new REST APIs or scripts starting the web services) are added under `smi-scalarlm/scripts`. 
   Use the same directory for SF sql worksheets.  



# Maintenance and Cleanup Scripts

## `docker` Artifacts
Use `scripts/clean-image.sh` to clean the local docker registry from a given image (the script stops and deletes all containers first).



<!-- 
r u n p o d . i o   E x p e r i m e n t s 
. . . . . . . . .   . . . . . . . . . . .
-->
# `runpod.io` Experiments

The section contains instructions to deploy the prebuilt `nvidia` and `x86` images `gdiamos/scalarlm-nvidia:latest` and `gdiamos/scalarlm-cpu:latest`
as pods on `runpod.io`.  

## Motivation and Objectives
The NVIDIA image is ~90Gibs. According to experiments conducted by Sudnya, this image size does not work on SPCS.  
We should instead create smaller images, keeping in each, only a single build target.  

To do so, we will start with a cpu image that we'll build locally.  


<!-- 
N V I D I A  I m a g e 
-->
The following constraints are in effect:
1. CUDA capabilities: We cannot use any CUDA library with the current image. `gdiamos/scalarlm-nvidia:latest` supports the following CUDA capabilities (as of 2025-05-20): 
   ```
   sm_50 sm_60 
   sm_70 sm_75 
   sm_80 sm_86 sm_90
   ```
   A mapping between capabilities and GPU types is contained [here](https://developer.nvidia.com/cuda-gpus) (read the left column "Compute Capability" without the decimal dot).  
2. `gpu_memory_utilization` and `max_model_length` in `infra/cray_infra/utils/default_config.py`: For inference set `gpu_memory_utilization = 0.95`.  
   `max_model_length` should decrease substantially from its default value (32767)


## `gdiamos/scalarlm-nvidia:latest ssh` Deployment

The docker image is `gdiamos/scalar-nvidia:latest` mentioned in [ScalarLM docs](https://www.scalarlm.com/docker/) and available on `hub.docker.com`.  
The `runpod.io` template used is [`cray-nvidia-latest ssh`](https://www.runpod.io/console/user/templates).  

To get an `SSH` connection to a `runpod.io` pod, except from the "runpod-standard" command (provided in [runpod documentation](https://docs.runpod.io/pods/configuration/use-ssh)) 
we add commands to:
1. activate a Python environment
2. set environment variables

The commands below ensure we can run `/app/cray/scripts/start_one_server.sh`. 
```bash
bash -c '
    apt update;
    DEBIAN_FRONTEND=noninteractive apt-get install openssh-server -y;
    mkdir -p ~/.ssh;cd $_;chmod 700 ~/.ssh;
    echo "$PUBLIC_KEY" >> authorized_keys;chmod 700 authorized_keys;
    echo "export INSTALL_ROOT=/app/cray" >>/etc/profile;
    echo "export PYTHONPATH=/app/cray/infra:/app/cray/sdk:/app/cray/ml:/app/cray/test" >>/etc/profile;
    echo "export SLURM_CONF=/app/cray/infra/slurm_configs/slurm.conf" >>/etc/profile;
    echo "export HF_HOME=/backstore/models/huggingface" >>/etc/profile;
    echo "source /app/.venv/bin/activate" >>/etc/profile;
    echo "cd /app/cray" >>/etc/profile;
    service ssh start;
    sleep infinity
'
```

__`runpod.io` particularities__  
1. To get an HTTP connection to the pod we also need to expose (in the web UI of `runpod.io`) the ports HTTP 8000 and HTTP 8001 (in addition to TCP 22)
and run `scripts/start_one_server.sh` on the ssh command line.  
2. 8000 and 8001 are exposed as HTTP (not TCP) ports. This requires that the hostname in the http requests sent to the pod are as 
   described in [`runpod.io`](https://docs.runpod.io/pods/configuration/expose-ports) i.e. `https://{pod-id}-8000/rumpod.io/...`.  
   We can expose 8000 and 8001 as TCP ports and follow a different client configuration: instead of the standard port, in our request we
   use the external port provided by runpod.

### Execution result
__SUCCESS__ (service starts)

__NB!__ if the model in `cray_infra/utils/default_config.py` is not available locally, the service may fail to start.  
This is a known issue attributed to async initializations.



## `gdiamos/scalarlm-nvidia:latest http` Deployment

The pod below automatically starts the uvicorn (HTTP) server.  
The `runpod.io` pod template is [`cray-nvidia-latest http`](https://www.runpod.io/console/user/templates).  

Again we need a `bash -c ...` command in the pod initialization field in the web UI. The following command starts additionally an ssh server:
```bash
bash -c '
    apt update;
    DEBIAN_FRONTEND=noninteractive apt-get install openssh-server -y;
    mkdir -p ~/.ssh;cd $_;chmod 700 ~/.ssh;
    echo "$PUBLIC_KEY" >> authorized_keys;chmod 700 authorized_keys;
    echo "export INSTALL_ROOT=/app/cray" >>/etc/profile;
    echo "export PYTHONPATH=/app/cray/infra:/app/cray/sdk:/app/cray/ml:/app/cray/test" >>/etc/profile;
    echo "export SLURM_CONF=/app/cray/infra/slurm_configs/slurm.conf" >>/etc/profile;
    echo "export HF_HOME=/backstore/models/huggingface" >>/etc/profile;
    echo "source /app/.venv/bin/activate" >>/etc/profile;
    echo "cd /app/cray" >>/etc/profile;
    service ssh start;
    source /app/cray/scripts/start_one_server.sh;
    sleep infinity
'
```

### Execution result
__SUCCESS__(service starts).   

__NB!__ if the model in `cray_infra/utils/default_config.py` is not available locally, the service may fail to start.  
This is a known issue attributed to async initializations.

### Notes
1. We need to `source` `/app/cray/scripts/start_one_server.sh` and `.venv/bin/activate` because the scripts are not executable. 
2. 8000 and 8001 are exposed as HTTP (not TCP) ports. This requires that the hostname in the http requests sent to the pod are as 
   described in [`runpod.io`](https://docs.runpod.io/pods/configuration/expose-ports) i.e. `https://{pod-id}-8000/rumpod.io/...`.



<!-- 
C P U  I m a g e 
-->
## `gdiamos/scalarlm-cpu:latest ssh` Deployment

The `runpod.io` pod template is [`scalarlm-amd-latest ssh`](https://www.runpod.io/console/user/templates). 
```bash
bash -c '
    apt update;
    DEBIAN_FRONTEND=noninteractive apt-get install openssh-server -y;
    mkdir -p ~/.ssh;cd $_;chmod 700 ~/.ssh;
    echo "$PUBLIC_KEY" >> authorized_keys;chmod 700 authorized_keys;
    echo "export INSTALL_ROOT=/app/cray" >>/etc/profile;
    echo "export PYTHONPATH=/app/cray/infra:/app/cray/sdk:/app/cray/ml:/app/cray/test" >>/etc/profile;
    echo "export SLURM_CONF=/app/cray/infra/slurm_configs/slurm.conf" >>/etc/profile;
    echo "export HF_HOME=/backstore/models/huggingface" >>/etc/profile;
    echo "source /app/.venv/bin/activate" >>/etc/profile;
    echo "cd /app/cray" >>/etc/profile;
    service ssh start;
    sleep infinity
'
```

### Execution result
__SUCCESS__ (Service starts)

__NB!__ if the model in `cray_infra/utils/default_config.py` is not available locally, the service may fail to start.  
This is a known issue attributed to async initializations.




<!-- 
L o c a l  E x p e r i m e n t s 
. . . . .  . . . . . . . . . . .
-->
# Local Experiments
The objective here is to run inference using small containers for arm64/v8 and x86 targets.  
We'll use them for local development and for development and testing on SPCS.  
We use a new M3 mac for the arm64/v8 target and and an old (2019) i9 mac and `runpod.io` for the x86 targets.


## `gdiamos/scalar-cpu:latest ssh` deployment on the `i9-mbp` host (`x86`)
```bash
target=cpu \
platform="linux/amd64" hf_cache="/app/cray/huggingface" \
bash -c '
   docker \
   run -it --rm \
   --platform ${platform} \
   --mount type=bind,src=$HOME/.cache/huggingface,dst=${hf_cache} \
   -p 8000:8000 -p 8001:8001 \
   -e HF_HOME=${hf_cache} \
   -e BASE_NAME=${target} \
   -e VLLM_TARGET_DEVICE=${target} \
   gdiamos/scalarlm-cpu:latest bash
'
```

### Execution result
__SUCCESS__ (service starts)

__NB!__ if the model in `cray_infra/utils/default_config.py` is not available locally, the service may fail to start.  
This is a known issue attributed to async initializations.  
Resolution: restart `start_one_server.sh`



## `supermassive-intelligence/scalarlm@main` build and deployment on the `M3-mbp` host (`arm64/v8`)

Build `supermassive-intelligence/Dockerfile` for `linux/arm64/v8` target architecture using the latest commit in `main`:  
```bash
repo=smi-scalarlm branch=main tag="arm" target=cpu platform="linux/arm64/v8" \
bash -c '
docker build \
   --platform ${platform} \
   --build-arg BASE_NAME=${target} \
   --build-arg VLLM_TARGET_DEVICE=${target} \
   -f Dockerfile \
   -t ${repo}-${branch}:${target}-${tag} \
   --shm-size=8g .
'
```

Run `smi-scalarlm-latest:cpu-arm64` on `arm64/v8` target (`bash` entrypoint)
```bash
repo=smi-scalarlm branch=main tag=arm target=cpu \
platform=linux/arm64/v8 hf_cache="/app/cray/huggingface" \
bash -c '
docker \
   run -it --rm \
   --platform ${platform} \
   --mount type=bind,src=$HOME/.cache/huggingface,dst=${hf_cache} \
   -p 8000:8000 -p 8001:8001 \
   -e HF_HOME=${hf_cache} \
   -e BASE_NAME=${target} \
   -e VLLM_TARGET_DEVICE=${target} \
   ${repo}-${branch}:${target}-${tag} bash
'
```

### Execution results
__FAILURE__ (Image buids, service starts but it is too slow with masint/tiny-random-llama and errs with meta-llama/Llama-3.2-1B-Insttuct)


### Comments 
If the model in `cray_infra/utils/default_config.py` is not available locally, the service may fail to start.  
This is a known issue attributed to async initializations.  
Resolution: restart `start_one_server.sh`



## `supermassive-intelligence/scalarlm@main` build and deployment on `i9-mbp` host (`linux/amd64`)
1. Objective: build `supermassive-intelligence/Dockerfile` for `linux/amd64` target architecture using the latest commit in `main`.
   I do this using `--platform linux/amd64` (rather than starting a Linux VM with docker using Multipass on `i9-mbp`).  
   ```bash
   git checkout main

   repo=smi-scalarlm branch=main tag="x86" target=cpu platform="linux/amd64" \
   bash -c '
      docker build \
      --platform ${platform} \
      --build-arg BASE_NAME=${target} \
      --build-arg VLLM_TARGET_DEVICE=${target} \
      -f Dockerfile \
      -t ${repo}-${branch}:${target}-${tag} \
      --shm-size=8g .
   '
   ```

### Execution result
__SUCCESS__ (the image is built)


### Comments 
The image cannot be built on an arm device just using `--platform=linux/amd`. `vLLM` dependencies from an `arm` host are not installed.  
__Build Warning found in main:__  
``` bash
1 warning found (use docker --debug to expand):
 - UndefinedVar: Usage of undefined variable '$PYTHONPATH' (line 146)
```
__Resolution:__ remove $PYTHONPATH from the beginning of line 146:  
```bash
ENV PYTHONPATH="${PYTHONPATH}:${INSTALL_ROOT}/infra"
```
This is corrected in `cpu.dockerfile` in branch `rai-37376`


2. Objective: start a `bash` shell in the container
   ```bash
   repo=smi-scalarlm branch=main tag="x86" target=cpu platform="linux/amd64" \
   hf_cache="/app/cray/huggingface" \
   bash -c '
   docker \
      run -it --rm \
      --platform ${platform} \
      --mount type=bind,src=$HOME/.cache/huggingface,dst=${hf_cache} \
      -p 8000:8000 -p 8001:8001 \
      -e HF_HOME=${hf_cache} \
      -e BASE_NAME=${target} \
      -e VLLM_TARGET_DEVICE=${target} \
      ${repo}-${branch}:${target}-${tag} bash
   '
   ```


3. Start the container service in the background
   ```bash
   mkdir -p var/huggingface 
   
   repo=smi-scalarlm branch=main tag="x86" target=cpu platform="linux/amd64" \
   hf_cache="/app/cray/huggingface" \
   bash -c '
   docker \
      run -d \
      --platform ${platform} \
      --mount type=bind,src=$HOME/.cache/huggingface,dst=${hf_cache} \
      -p 8000:8000 -p 8001:8001 \
      -e HF_HOME=${hf_cache} \
      -e BASE_NAME=${target} \
      -e VLLM_TARGET_DEVICE=${target} \
      ${repo}-${branch}:${target}-${tag} scripts/start_one_server.sh \
   >>var/${repo}-${branch}:${target}-${tag}.log
   '
   ```

### Execution result  
__UNKNOWN__   
<span style="color: red">
Service starts but I have not tested the service response to a model other than `masint/tiny-random-llama`
</style>

### Notes
If the model in `cray_infra/utils/default_config.py` is not available locally, the service may fail to start.  
This is a known issue attributed to async initializations.  
__Resolution:__ restart `start_one_server.sh`. 
