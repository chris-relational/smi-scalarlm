# Repository forking and cloning

1. I forked `supermassive-intelligence/scalarlm` (public repo) to `chris-relational/smi-scalarlm` 
   (this was done from the `supermassive-intelligence/scalarlm` page on GitHub).

2. I cloned `supermassive-intelligence/scalarlm` locally under `remotes/chris-relational` as `smi-scalarlm` (that is, I used the name of the original repository).

3. I did all these to be able to fetch from the original repo and push to the forked repo:  
```bash
cd smi-scalarlm
git remote set-url origin --push git@chris-relational-github:chris-relational/ 
smi-scalarlm.git 
```

Now I have a local repository with an upstream that fetches from `massive-intelligence/scalarlm` and pushes to `chris-relational/smi-scalarlm`.


# Container Deployments

## `scalarlm-nvidia-latest ssh` Deployment
Here we use the docker image `gdiamos/cray-nvidia:latest` (available on `hub.docker.com` and indicated in [ScalarLM docs](https://www.scalarlm.com/docker/).  

To get an `SSH` connection to a `runpod.io` pod, except from the "standard" command (detailed in [runpod documentation](https://docs.runpod.io/pods/configuration/use-ssh)) we need commands to:
1. activate a Python environment
2. set environment variables

The above ensure that we can run `/app/cray/scripts/start_one_server.sh`. 

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



# Local Cleanup Scripts

## `docker` Artifacts

Use the following to clean your local docker registry from all `cray` builds:  

```bash
docker ps -aq | xargs docker container stop; docker rm $(docker ps -aq);
docker images | python -c '
from sys import stdin
for line in stdin:
   fields = line.strip().split()
   print(fields[0], fields[1], sep=":")
' | grep 'scalarlm/cray' | xargs docker rmi
```

