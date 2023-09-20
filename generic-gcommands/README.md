# gcommands plugin

Some commands to make working with gcloud easier.

## usage

To manage environments use [configurations](https://cloud.google.com/sdk/docs/configurations).
These scripts will not override the configurations you are in and will display the current configuration when run.

You will need to have gcloud installed, on macOS you can do this with [brew](https://formulae.brew.sh/cask/google-cloud-sdk) `brew install --cask google-cloud-sdk`

You will need to set an environment variable `GUSER` to match your email user name. 
You can optionally define a variable `GPREFIX` to prefix your instance names (generally the practice at Replicated is also to use your email user name).
If you've used brew to install gcloud the configuration would be:

```zsh
# Configure gcommands plugin
GUSER='chriss'
GPREFIX='chriss'

# Setup gcloud commands
source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
```
### expires-on

Instances are created by default with a lifetime of one day. If you would like to change this, provide the -d argument before the image and instance names with a valid `date` duration string (implementation dependent; for macOS/BSD `date`, `1d` == one day, `1w` == one week, etc; for Linux/GNU `date`, `1 day` == one day, `1 week` == 1 week, etc). If the instance must not be automatically reaped, provide `never` in the place of the duration string.

Example Usage:

```zsh
╭chris:~/.oh-my-zsh %
╰➤ gcreate -d 1d rhel-8-v20210817 chriss-test-rh
Configuration: qa-c
+gcreate:15> echo chriss-test-rh
+gcreate:15> gcloud compute instances create chriss-test-rh --labels 'owner=chriss' '--machine-type=n1-standard-4' '--subnet=default' '--network-tier=PREMIUM' '--maintenance-policy=MIGRATE' '--service-account=846065462912-compute@developer.gserviceaccount.com' '--scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append' '--image=rhel-8-v20210817' '--image-project=rhel-cloud' '--boot-disk-size=200GB' '--boot-disk-type=pd-standard' --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring '--reservation-affinity=any'
Created [https://www.googleapis.com/compute/v1/projects/replicated-qa/zones/us-central1-c/instances/chriss-test-rh].
WARNING: Some requests generated warnings:
 - Disk size: '200 GB' is larger than image size: '20 GB'. You might need to resize the root repartition manually if the operating system does not support automatic resizing. See https://cloud.google.com/compute/docs/disks/add-persistent-disk#resize_pd for details.

NAME            ZONE           MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP   STATUS
chriss-test-rh  us-central1-c  n1-standard-4               10.128.0.93  34.72.173.60  RUNNING

╭chris:~/.oh-my-zsh %
╰➤ glist
Configuration: qa-c
NAME            ZONE           MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP   STATUS
chriss-test-rh  us-central1-c  n1-standard-4               10.128.0.93  34.72.173.60  RUNNING
```

