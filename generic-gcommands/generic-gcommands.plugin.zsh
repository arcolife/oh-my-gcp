#!/bin/bash
# GUSER=
# GPREFIX=

if (( ! ${+commands[gcloud]} ));then
  >&2 echo "gcloud not installed, not loading generic-gcommands plugin"
  return 1
fi

genv() {
  >&2 echo "Configuration: $(cat ~/.config/gcloud/active_config)"
}

glist() {
  genv
  gcloud compute instances list --filter="labels.owner:${GUSER}"
}

getdate() {
  local duration="$1"
  case $OSTYPE in 
    darwin*)
      [ -z "$duration" ] && duration="1d" || :
      date "-v+${duration}" '+%Y-%m-%d'
      ;;
    linux*)
      [ -z "$duration" ] && duration="1 day" || :
      date -d "${duration}" '+%Y-%m-%d'
      ;;
  esac
}

gimage() {
  IMAGE_FAMILY="${1:-ubuntu-2204-lts}"
  gcloud compute images list --filter="family='$IMAGE_FAMILY'" --sort-by="~creationTimestamp" --limit=1 --format="json(name)" | jq -r '.[].name'
}

gcreate() {
  genv
  local usage='Usage: gcreate [-d duration|never] <IMAGE> <INSTANCE_NAMES>'
  local expires
  while getopts ":d:" opt; do
    case $opt in
      d)
        [ "$OPTARG" = "never" ] && expires="never" || expires="$(getdate "${OPTARG}")"    
        ;;
    esac
  done
  shift "$((OPTIND-1))"
  [ -z "$expires" ] && expires="$(getdate)" || :
  if [ "$#" -lt 2 ]; then echo "${usage}"; return 1; fi
  local machine_type
  machine_type=""
  if [ ! -z "$GMACHINETYPE" ]; then
    echo "Using specified GCP machine type '${GMACHINETYPE}' (from \$GMACHINETYPE)"
    machine_type="${GMACHINETYPE}"
  else
    machine_type="n1-standard-8"
    echo "Using default GCP machine type '${machine_type}'"
  fi
  local min_cpu_platform
  min_cpu_platform=""
  if [[ "$(echo "$machine_type" | cut -d- -f1)" == "n1" ]]; then
    echo "Adding '--min-cpu-platform=Intel Haswell' for nested virtualization"
    min_cpu_platform="--min-cpu-platform=Intel Haswell"
  fi
  local image
  image="$(gcloud compute images list | grep -v arm | grep "$1" | awk 'NR == 1')"
  if [ -z "${image}" ]; then image="$(gcloud compute images list --show-deprecated --sort-by=~creationTimestamp | grep "$1" | awk 'NR == 1')"; fi
  if [ -z "${image}" ]; then echo "gcreate: unknown image $image"; echo "${usage}"; return 1; fi
  local image_name
  image_name="$(echo "${image}" | awk '{print $1}')"
  local image_project
  image_project="$(echo "${image}" | awk '{print $2}')"
  local default_service_account
  default_service_account="$(gcloud iam service-accounts list | grep -o '[0-9]*\-compute@developer.gserviceaccount.com')"
  shift
  local instance_names=("$@")
  if [ -n "${GPREFIX}" ]; then
    instance_names=($(echo ${instance_names} | sed "s/[^ ]* */${GPREFIX}-&/g"))
  fi
  (set -x; gcloud compute instances create ${instance_names[@]} \
    --labels owner="${GUSER}",email="${GUSER}__64__projectsiege__46__org",expires-on="${expires}" \
    --machine-type="${machine_type}" \
    --enable-nested-virtualization \
    $min_cpu_platform \
    --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --can-ip-forward \
    --service-account="${default_service_account}" \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --image="${image_name}" --image-project="${image_project}" \
    --boot-disk-size=30GB --boot-disk-type=pd-ssd \
    --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any)
    # --create-disk size=50GB,type=pd-ssd,auto-delete=yes \
}

gstart() {
  genv
  local usage="Usage: gstart [INSTANCE_NAMES]"
  if [ "$#" -lt 1 ]; then echo "${usage}"; return 1; fi
  local instance_name_prefix="$1"
  gcloud compute instances start $(gcloud compute instances list --filter="labels.owner:${GUSER}" | awk '{if(NR>1)print}' | grep TERMINATED | grep "^${instance_name_prefix}" | awk '{print $1}' | xargs echo)
}

gstop() {
  genv
  local usage="Usage: gstop [INSTANCE_NAMES]"
  if [ "$#" -lt 1 ]; then echo "${usage}"; return 1; fi
  local instance_name_prefix="$1"
  gcloud compute instances stop $(gcloud compute instances list --filter="labels.owner:${GUSER}" | awk '{if(NR>1)print}' | grep RUNNING | grep "^${instance_name_prefix}" | awk '{print $1}' | xargs echo)
}

gdelete() {
  genv
  local usage="Usage: gdelete [INSTANCE_NAME_PREFIX]"
  local instance_name_prefix="$1"
  if [ -n "${GPREFIX}" ]; then
    instance_name_prefix="${GPREFIX}-${instance_name_prefix}"
  fi
  if ! gcloud compute instances list --filter="labels.owner:${GUSER}" | awk '{if(NR>1)print}' | grep -q "^${instance_name_prefix}" ; then echo "no instances match \"labels.owner:${GUSER}\""; echo "${usage}"; return 1; fi
  gcloud compute instances delete --delete-disks=all $(gcloud compute instances list --filter="labels.owner:${GUSER}" | awk '{if(NR>1)print}' | grep "^${instance_name_prefix}" | awk '{print $1}' | xargs echo)
}

gonline() {
  genv
  local usage="Usage: gonline [INSTANCE_NAMES]"
  if [ "$#" -lt 1 ]; then echo "${usage}"; return 1; fi
  local instance
  for instance in "$@"; do
    local instance_name="${instance}"
    if [ -n "${GPREFIX}" ]; then
      instance_name="${GPREFIX}-${instance_name}"
    fi
    (set -x; gcloud compute instances add-access-config "${instance_name}" --access-config-name="external-nat")
  done
}

gairgap() {
  genv
  local usage="Usage: gairgap [INSTANCE_NAMES]"
  if [ "$#" -lt 1 ]; then echo "${usage}"; return 1; fi
  local instance
  for instance in "$@"; do
    local instance_name="${instance}"
    if [ -n "${GPREFIX}" ]; then
      instance_name="${GPREFIX}-${instance_name}"
    fi
    local access_config_name
    access_config_name="$(gcloud compute instances describe "${instance_name}" --format="value(networkInterfaces[0].accessConfigs[0].name)")"
    (set -x; gcloud compute instances delete-access-config "${instance_name}" --access-config-name="${access_config_name}")
  done
}

gssh-forward() {
  # genv
  local usage="Usage: gssh-forward [INSTANCE_NAME]"
  if [ "$#" -ne 1 ]; then echo "${usage}"; return 1; fi
  local instance_name="$1"
  if [ -n "${GPREFIX}" ]; then
    instance_name="${GPREFIX}-${instance_name}"
  fi
  local natip=$(gcloud compute instances describe "${instance_name}" --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
  local ip=$(gcloud compute instances describe "${instance_name}" --format="value(networkInterfaces[0].networkIP)")
  # gcloud compute ssh --tunnel-through-iap "${instance_name}" -- -L 8800:$address:8800 -L 8888:$address:8888
  ssh -L 8800:$ip:8800 -L 8888:$ip:8888 $natip
}

gssh() {
  genv
  local usage="Usage: gssh [INSTANCE_NAME]"
  if [ "$#" -ne 1 ]; then echo "${usage}"; return 1; fi
  local instance_name="$1"
  if [ -n "${GPREFIX}" ]; then
    instance_name="${GPREFIX}-${instance_name}"
  fi
  while true; do
    start_time="$(date -u +%s)"
    gcloud compute ssh --tunnel-through-iap "${instance_name}"
    end_time="$(date -u +%s)"
    elapsed="$(bc <<<"$end_time-$start_time")"
    if [ "${elapsed}" -gt "60" ]; then # there must be a better way to do this
      return
    fi
    sleep 2
  done
}

gdisk() {
  genv
  local usage="Usage: gdisk [DISK_NAMES]"
  if [ "$#" -lt 1 ]; then echo "${usage}"; return 1; fi
  local disk_names=("$@")
  if [ -n "${GPREFIX}" ]; then
    disk_names=($(echo ${disk_names} | sed "s/[^ ]* */${GPREFIX}-disk-&/g"))
  fi
  (set -x; gcloud compute disks create ${disk_names[@]} \
    --labels owner="${GUSER}" \
    --type=pd-balanced --size=100GB)
}

gattach() {
  genv
  local usage="Usage: gattach [INSTANCE_NAME] [DISK_NAME]"
  if [ "$#" -ne 2 ]; then echo "${usage}"; return 1; fi
  local instance_name="$1"
  local disk_name="disk-$2"
  local device_name="$1-disk-$2"
  if [ -n "${GPREFIX}" ]; then
    instance_name="${GPREFIX}-${instance_name}"
    disk_name="${GPREFIX}-${disk_name}"
    device_name="${GPREFIX}-${device_name}"
  fi
  (set -x; gcloud compute instances attach-disk "${instance_name}" --disk="${disk_name}" --device-name="${device_name}")
}

gtag() {
  genv
  local usage="Usage: gattach [INSTANCE_NAME] [comma-delimited list of TAGS]"
  if [ "$#" -ne 2 ]; then echo "${usage}"; return 1; fi
  local instance_name="$1"
  if [ -n "${GPREFIX}" ]; then
    instance_name="${GPREFIX}-${instance_name}"
  fi
  local tags="$2"
  (set -x; gcloud compute instances add-tags "${instance_name}" --tags="${tags}")
}
