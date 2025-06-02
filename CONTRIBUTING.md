# Table of Contents
[Repository forking and cloning](#repository-forking-and-cloning)  
[`runpod.io` Experiments](#runpodio-experiments)  
[Local Experiments](#local-experiments)
[Local Cleanup Scripts](#local-cleanup-scripts)  



# Repository forking and cloning
`supermassive-intelligence/scalarlm` is forked to `chris-relational/smi-scalarlm` and the latter is cloned locally



<!-- r u n p o d . i o   E x p e r i m e n t s -->
# `runpod.io` Experiments


<!-- N V I D I A -->
The section contains instructions to deploy the prebuilt `nvidia` and `amd` images `gdiamos/scalarlm-nvidia:latest` and `gdiamos/scalarlm-amd:latest`
as pods on `runpod.io`.  

The following constraints must be taken into account:
1. CUDA capabilities: We cannot use any CUDA library with the current image. `gdiamos/scalarlm-nvidia:latest` supports the following CUDA capabilities (as of 2025-05-20): 
   ```
   sm_50 sm_60 
   sm_70 sm_75 
   sm_80 sm_86 sm_90
   ```
   A mapping between capabilities and GPU types is contained [here](https://developer.nvidia.com/cuda-gpus) (read the left column "Compute Capability" without the decimal dot).  
2. `gpu_memory_utilization` and `max_model_length` in `infra/cray_infra/utils/default_config.py`: For inference set `gpu_memory_utilization = 0.95`.  
   `max_model_length` should decrease substantially from its default value (32767)



## `scalarlm-nvidia-latest ssh` Deployment

The docker image is `gdiamos/scalar-nvidia:latest` mentioned in [ScalarLM docs](https://www.scalarlm.com/docker/) and available on `hub.docker.com`.  
The `runpod.io` template is [`cray-nvidia-latest ssh`](https://www.runpod.io/console/user/templates).  

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
    /app/.venv/bin/activate;
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



## `scalarlm-nvidia-latest http` Deployment

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
    source /app/.venv/bin/activate;
    service ssh start;
    source /app/cray/scripts/start_one_server.sh;
    sleep infinity
'
```

__Notes__  
1. We need to `source` `/app/cray/scripts/start_one_server.sh` and `.venv/bin/activate` because the scripts are not executable. 
2. 8000 and 8001 are exposed as HTTP (not TCP) ports. This requires that the hostname in the http requests sent to the pod are as 
   described in [`runpod.io`](https://docs.runpod.io/pods/configuration/expose-ports) i.e. `https://{pod-id}-8000/rumpod.io/...`.



## `scalarlm-amd-latest ssh` Deployment

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
    /app/.venv/bin/activate;
    service ssh start;
    sleep infinity
'
```

__Execution result__
. . .



<!-- L o c a l  E x p e r i m e n t s -->
# Local Experiments
The objective here is to run inference using small containers for arm64/v8 and amd64 targets.  
We'll use them for local development and for development and testing on SPCS.  
We use a new M3 mac for the arm64/v8 target and and an old (2019) i9 mac and `runpod.io` for the amd64 targets.


## `gdiamos/scalar-amd:latest` deployment on `amd64` target locally (`i9-mbp`)

```bash
mkdir -p var/huggingface

target=cpu \
platform="linux/amd64" hf_cache="/app/cray/huggingface"; \
docker \
   run -it --rm \
   --platform ${platform} \
   --mount type=bind,src=./var/huggingface,dst=${hf_cache} \
   -p 8000:8000 -p 8001:8001 \
   -e HF_HOME=${hf_cache} \
   -e BASE_NAME=${target} \
   -e VLLM_TARGET_DEVICE=${target} \
   gdiamos/scalarlm-amd:latest bash
```

__Execution result__
. . .



## `gdiamos/scalarlm-amd:latest` deployment on `runpod.io`
Deploying containers on runpod require some additional steps that we include in the starting command of the container as shown below.  
The purspose is to install and start an SSH server (`sshd`) that we will use to get a commandline to the running pod.

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
    /app/.venv/bin/activate;
    service ssh start;
    sleep infinity
'
```

__Execution Result__ (FAILED)
```bash
latest Pulling from gdiamos/cray-cpu
Digest: sha256:fffd574f8f2775785e670dfb150a0fc0d60eaa732210c82279a87c8a30581716
Status: Image is up to date for gdiamos/cray-cpu:latest
start container for gdiamos/cray-cpu:latest: begin
error starting container: Error response from daemon: failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: unable to apply cgroup configuration: mkdir /sys/fs/cgroup/memory/docker/80b50f8067085467bc0140eba47ad95be1b800bcbf56a1042aff2fa8251cd869: no space left on device: unknown
```



## `supermassive-intelligence/scalarlm@main` build and deployment on `arm64/v8` target locally (`M3-mbp`)

1. Build `supermassive-intelligence/Dockerfile` for `linux/arm64/v8` target architecture using the latest commit in `main`:  
   ```bash
   repo=smi-scalarlm commit=latest tag="arm" target=cpu platform="linux/arm64/v8"; \
   docker build \
      --platform ${platform} \
      --build-arg BASE_NAME=${target} \
      --build-arg VLLM_TARGET_DEVICE=${target} \
      -f Dockerfile \
      -t ${repo}-${commit}:${target}-${tag} \
      --shm-size=8g .
   ```

__Execution result:__ BUILT


2. Run `smi-scalarlm-latest:cpu-arm64` on `M3-mbp`
   ```bash
   repo=smi-scalarlm commit=latest tag=arm target=cpu \
   platform="linux/arm64/v8" hf_cache="/app/cray/huggingface"; \
   docker \
      run -it --rm \
      --platform ${platform} \
      --mount type=bind,src=./var/huggingface,dst=${hf_cache} \
      -p 8000:8000 -p 8001:8001 \
      -e HF_HOME=${hf_cache} \
      -e BASE_NAME=${target} \
      -e VLLM_TARGET_DEVICE=${target} \
      ${repo}-${commit}:${target}-${tag} bash
   ```

__Execution result:__ The service starts. Tested with several HF (Llama) models of moderate sizes (<=8b parameters).  
__NB!__ if the model selected in `cray_infra/utils/default_config.py` is not downloaded already, the server may fail to start. This
is a known issue attributed to multiprocessing. To pass it, just run the server again.  



## `supermassive-intelligence/scalarlm@main` build and deployment on `amd64` target locally (`i9-mbp`)
1. Build `supermassive-intelligence/Dockerfile` for `linux/amd64` target architecture using the latest commit in `main`:  
   ```bash
   git checkout main

   repo=smi-scalarlm commit=latest tag="amd" target=cpu platform="linux/amd64"; \
   docker build \
      --platform ${platform} \
      --build-arg BASE_NAME=${target} \
      --build-arg VLLM_TARGET_DEVICE=${target} \
      -f Dockerfile \
      -t ${repo}-${commit}:${target}-${tag} \
      --shm-size=8g .
   ```

__Execution result:__ BUILT  
__NB!__ The image cannot be built on an arm device just using `--platform=linux/amd`. `vLLM` dependencies from an `arm` host are not installed.  
__Build Results:__  
``` bash
1 warning found (use docker --debug to expand):
 - UndefinedVar: Usage of undefined variable '$PYTHONPATH' (line 146)
```
Resolution: remove $PYTHONPATH from the beginning of 


2. Run the image `smi-scalarlm-latest:cpu-arm64` built above  
   ```bash
   repo=smi-scalarlm commit=latest tag="amd" target=cpu platform="linux/amd64" \
   platform="linux/arm64/v8" hf_cache="/app/cray/huggingface"; \
   docker \
      run -it --rm \
      --platform ${platform} \
      --mount type=bind,src=./var/huggingface,dst=${hf_cache} \
      -p 8000:8000 -p 8001:8001 \
      -e HF_HOME=${hf_cache} \
      -e BASE_NAME=${target} \
      -e VLLM_TARGET_DEVICE=${target} \
      ${repo}-${commit}:${target}-${tag} bash
   ```

__Execution result__ (FAILED)  
No execution due to error in the build script


# Local Cleanup Scripts

## `docker` Artifacts
Use `scripts/clean-image.sh` to clean the local docker registry from a given image (the script stops and deletes all containers first).
