# Table of Contents
[Repository forking and cloning](#repository-forking-and-cloning)  
[Experiments: deployment of NVIDIA images on `runpod.io`](#experiments-deployment-of-nvidia-images-on-runpodio)  
[Experiments: cpu image deployments](#experiments-cpu-image-deployments)
[Local Cleanup Scripts](#local-cleanup-scripts)  



# Repository forking and cloning

1. Forked `supermassive-intelligence/scalarlm` (public repo) to `chris-relational/smi-scalarlm` 
2. Cloned `supermassive-intelligence/scalarlm` locally under `remotes/chris-relational` as `smi-scalarlm` (that is, I used the name of the original repository).
3. The purpose is to be able to fetch from the original repo and push to the forked repo i.e:  
```bash
cd smi-scalarlm
git remote set-url origin --push git@chris-relational-github:chris-relational/smi-scalarlm.git 
```
Now we have a local repository with an upstream that fetches from `massive-intelligence/scalarlm` and pushes to `chris-relational/smi-scalarlm`.



<!-- N V I D I A  E x p e r i m e n t s -->
# Experiments: deployment of NVIDIA images on `runpod.io`
The section contains instructions to deploy the prebuilt nvidia image `gdiamos/cray-nvidia:latest` as a pod on `runpod.io`.  

The following constraints must be taken into account:
1. CUDA capabilities: We cannot use any CUDA library with the current image. `gdiamos/cray-nvidia:latest` supports the following CUDA capabilities (as of 2025-05-20): 
   ```
   sm_50 sm_60 
   sm_70 sm_75 
   sm_80 sm_86 sm_90
   ```
   A mapping between capabilities and GPU types is contained [here](https://developer.nvidia.com/cuda-gpus) (read the left column "Compute Capability" without the decimal dot).  
2. `gpu_memory_utilization` and `max_model_length` in `infra/cray_infra/utils/default_config.py`: For inference set `gpu_memory_utilization = 0.95`.  
   `max_model_length` should decrease substantially from its default value (32767)


## Deployment of `scalarlm-nvidia-latest ssh` runpod template
We use the docker image `gdiamos/cray-nvidia:latest` designated in [ScalarLM docs](https://www.scalarlm.com/docker/) (available on `hub.docker.com`).  

To get an `SSH` connection to a `runpod.io` pod, except from the "runpod-standard" command (provided in [runpod documentation](https://docs.runpod.io/pods/configuration/use-ssh)) we need commands to:
1. activate a Python environment
2. set environment variables

These ensure that we can run `/app/cray/scripts/start_one_server.sh`. 
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

### Notes
1. To get an HTTP connection to the pod we also need to expose (in the web UI of `runpod.io`) the ports HTTP 8000 and HTTP 8001 (in addition to TCP 22)
and run `scripts/start_one_server.sh` on the ssh command line.  
2. 8000 and 8001 are exposed as HTTP (not TCP) ports. This requires that the hostname in the http requests sent to the pod are as 
   described in [`runpod.io`](https://docs.runpod.io/pods/configuration/expose-ports) i.e. `https://{pod-id}-8000/rumpod.io/...`.  
   We can expose 8000 and 8001 as TCP ports and follow a different client configuration: instead of the standard port, in our request we
   use the external port provided by runpod.



## `scalarlm-nvidia-latest http` Deployment
Below we start a pod that automatically runs the uvicorn (HTTP) server.
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

### Notes
1. We need to `source` `/app/cray/scripts/start_one_server.sh` and `.venv/bin/activate` because the scripts are not executable. 
2. 8000 and 8001 are exposed as HTTP (not TCP) ports. This requires that the hostname in the http requests sent to the pod are as 
   described in [`runpod.io`](https://docs.runpod.io/pods/configuration/expose-ports) i.e. `https://{pod-id}-8000/rumpod.io/...`.



<!-- C P U  E x p e r i m e n t s -->
# Experiments: image build and deployment for amd64 and arm64/v8 targets
The objective here is to run inference using small containers for amd64 architectures. We'll use them for local development and
for development and testing on SPCS.  


## `gdiamos/cray-cpu:latest` deployment on M3-macbookpro
```bash
target=cpu platform="linux/amd64"; \   
docker \
   run -it --rm \
   --platform ${platform} \
   -p 8000:8000 -p 8001:8001 \
   -e BASE_NAME=${target} \
   -e VLLM_TARGET_DEVICE=${target} \
   gdiamos/scalarlm-amd:latest bash
```

__Execution result__ (FAILED)
```bash
root@48f559612949:/app/cray# scripts/start_one_server.sh
...
+ slurmctld
+ slurmd
+ python -m cray_infra.one_server.main
scripts/start_one_server.sh: line 17:    56 Illegal instruction     python -m cray_infra.one_server.main

```


## `gdiamos/cray-cpu:latest` deployment on `runpod.io`
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


## Build `supermassive-intelligence/scalarlm@main` on my old i9-mbp with `--platform=linux/amd64/v8` and run
1. Build `supermassive-intelligence/Dockerfile` for `linux/amd64` target architecture using the latest commit in `main`:  
   ```bash
   repo=smi-scalarlm commit=latest tag="amd64" target=cpu platform="linux/amd64"; \
   docker build \
      --platform ${platform} \
      --build-arg BASE_NAME=${target} \
      --build-arg VLLM_TARGET_DEVICE=${target} \
      -f Dockerfile \
      -t ${repo}-${commit}:${target}-${tag} \
      --shm-size=8g .
   ```

__Execution result:__ PASSED


2. Run the image `smi-scalarlm-latest:cpu-arm64` built above  
   ```bash
   repo=smi-scalarlm commit=latest tag=arm64 target=cpu \
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



## Build `supermassive-intelligence/scalarlm@main` on M3-macbookpro with `--platform=linux/arm64/v8` and run
1. Build `supermassive-intelligence/Dockerfile` for `linux/arm64/v8` target architecture using the latest commit in `main`:  
   ```bash
   env repo=smi-scalarlm commit=latest tag="arm64" target=cpu platform="linux/arm64/v8"; \
   docker build \
      --platform ${platform} \
      --build-arg BASE_NAME=${target} \
      --build-arg VLLM_TARGET_DEVICE=${target} \
      -f Dockerfile \
      -t ${repo}-${commit}:${target}-${tag} \
      --shm-size=8g .
   ```

__Execution result:__ PASSED


2. Run the image `smi-scalarlm-latest:cpu-arm64` built above  
   ```bash
   repo=smi-scalarlm commit=latest tag=arm64 target=cpu \
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
