#!/bin/bash

# Deploy/destroy K8s cluster

# REQUIREMENTS/RECOMMENDATIONS:
## * Installed awscli, kops, kubectl, jq
## * administrative access to destination AWS account

# CONFIGURATION:
## Basic defaults (can be re-set with command line parameters, see --help):
CLUSTER_NAME_PREFIX=""
CLUSTER_NAME_POSTFIX="k8s.local"
REGION="eu-central-1"
ACTION="create"
USE_EXTERNAL_IAM_POLICIES="false"
## Advanced:
AWS_AZS="eu-central-1a"
K8S_NODE_COUNT="2"
DISABLE_NATGW="false"
SUBNETS_TAGGING="true"
CROSS_ACCOUNT_ROLE_SESSION_DURATION="7200"
DEFAULT_TAGS="kops=true"
TAGS="${DEFAULT_TAGS}"
K8S_MASTER_INSTANCE_TYPE="m3.medium"
K8S_NODE_INSTANCE_TYPE="m3.medium"
K8S_MIN_HEALTHY_MASTERS="1"
K8S_MIN_HEALTHY_NODES="1"
HTTP_PROXY_EXCLUDES="compute.internal"


# USAGE FUNCTION:
usage() {
    cat <<EOF
Usage: ./kentrikos_k8s_cluster_deploy.sh [OPTIONS]
Creates or destroys K8s cluster with kops.

Arguments:
    -c | --cluster-name-prefix STRING (mandatory)
    -x | --cluster-name-postfix STRING (k8s.local is default and supported only by now)
    -r | --region NAME
    -v | --vpc-id ID (mandatory)
    -z | --az AZ_NAMES (comma-separated list, no spaces, eu-central-1a by default, for HA cluster use 'zone-1,zone-2,zone-3' notation)
    -s | --subnets SUBNET_IDS (comma-separated list, no spaces)
    -n | --node-count NUMBER_OF_MINIONS
    -a | --action [create (default), destroy]
    -p | --http-proxy HOST[:PORT] (just hostname + optional port e.g. proxy.example.com:8080)
    -u | --assume-cross-account-role ARN (script will assume cross-account role)
    -w | --disable-natgw (don't use NAT gateway for egress traffic - e.g. for peered VPCs with HTTP proxy)
    -l | --tags LIST (comma-separated list of key-value pairs, no spaces. i.e. "Environment=TEST,Date=2018-01-01". Used to tag all instance groups. "kops=true" tag is added by default.)
    -g | --disable-subnets-tagging (don't tag/untag subnets with cluster name on create/destroy. Warning: it may result in non-working K8s/ELB integration for exposing services.)
    -m | --master-instance-type STRING (choose instance size for master nodes)
    -d | --node-instance-type STRING (choose instance size for worker nodes)
    -t | --masters-iam-instance-profile-arn STRING (mandatory, ARN of pre-existing instance profile for master instances)
    -b | --nodes-iam-instance-profile-arn STRING (mandatory, ARN of pre-existing instance profile for worker instances)
    -k | --ssh-keypair-name STRING (optional, name of existing SSH keypair on AWS account, to be used for cluster instances)"
    -h | --help
EOF
}


# PARSE COMMAND LINE PARAMETERS:
OPTS=$(getopt -o c:x:r:v:z:a:s:n:p:u:l:m:d:t:b:k:wgh --long cluster-name-prefix:,cluster-name-postfix:,region:,vpc-id:,az:,action:,subnets:,node-count:,http-proxy:,assume-cross-account-role:,tags:,master-instance-type:,node-instance-type:,masters-iam-instance-profile-arn:,nodes-iam-instance-profile-arn:,ssh-keypair-name:,disable-natgw,disable-subnets-tagging,help -n 'parse-options' -- "$@")
if [ $? != 0 ]; then usage; exit 1; fi

eval set -- "$OPTS"

while true; do
  case "$1" in
    -c | --cluster-name-prefix ) CLUSTER_NAME_PREFIX="$2"; shift; shift ;;
    -x | --cluster-name-postfix ) CLUSTER_NAME_POSTFIX="$2"; shift; shift ;;
    -r | --region ) REGION="$2"; shift; shift ;;
    -v | --vpc-id ) VPC_ID="$2"; shift; shift ;;
    -z | --az ) AWS_AZS="$2"; shift; shift ;;
    -s | --subnets ) AWS_SUBNETS="$2"; shift; shift ;;
    -n | --node-count ) K8S_NODE_COUNT="$2"; shift; shift ;;
    -a | --action ) ACTION="$2"; shift; shift ;;
    -p | --http-proxy ) HTTP_PROXY_PARAM="$2"; shift; shift ;;
    -u | --assume-cross-account-role ) CROSS_ACCOUNT_ROLE="$2"; shift; shift ;;
    -w | --disable-natgw ) DISABLE_NATGW="true"; shift ;;
    -l | --tags ) TAGS="${DEFAULT_TAGS},$2"; shift; shift ;;
    -g | --disable-subnets-tagging ) SUBNETS_TAGGING="false"; shift ;;
    -m | --master-instance-type ) K8S_MASTER_INSTANCE_TYPE="$2"; shift; shift ;;
    -n | --node-instance-type ) K8S_NODE_INSTANCE_TYPE="$2"; shift; shift ;;
    -t | --masters-iam-instance-profile-arn ) K8S_MASTERS_IAM_INSTANCE_PROFILE_ARN="$2"; shift; shift ;;
    -b | --nodes-iam-instance-profile-arn ) K8S_NODES_IAM_INSTANCE_PROFILE_ARN="$2"; shift; shift ;;
    -k | --ssh-keypair-name ) AWS_SSH_KEYPAIR_NAME="$2"; shift; shift ;;
    -h | --help ) usage; exit 0; shift; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ -z "${CLUSTER_NAME_PREFIX}" ];
then
    usage; exit 1;
fi

cat <<EOF
-----------------------------------------------------------
INPUT PARAMETERS AND IMPORTANT VARIABLES:

ACTION:                              : $ACTION
CLUSTER_NAME_PREFIX                  : $CLUSTER_NAME_PREFIX
CLUSTER_NAME_POSTFIX                 : $CLUSTER_NAME_POSTFIX
REGION                               : $REGION
VPC_ID                               : $VPC_ID
AWS_AZS                              : $AWS_AZS
AWS_SUBNETS                          : $AWS_SUBNETS
HTTP_PROXY_PARAM                     : $HTTP_PROXY_PARAM
HTTP_PROXY_EXCLUDES                  : $HTTP_PROXY_EXCLUDES
CROSS_ACCOUNT_ROLE                   : $CROSS_ACCOUNT_ROLE
DISABLE_NATGW                        : $DISABLE_NATGW
TAGS                                 : $TAGS
SUBNETS_TAGGING                      : $SUBNETS_TAGGING
K8S_NODE_COUNT                       : $K8S_NODE_COUNT
K8S_MASTER_INSTANCE_TYPE             : $K8S_MASTER_INSTANCE_TYPE
K8S_NODE_INSTANCE_TYPE               : $K8S_NODE_INSTANCE_TYPE
K8S_MASTERS_IAM_INSTANCE_PROFILE_ARN : $K8S_MASTERS_IAM_INSTANCE_PROFILE_ARN
K8S_NODES_IAM_INSTANCE_PROFILE_ARN   : $K8S_NODES_IAM_INSTANCE_PROFILE_ARN
AWS_SSH_KEYPAIR_NAME                 : $AWS_SSH_KEYPAIR_NAME
-----------------------------------------------------------
EOF
echo "ENVIRONMENT:"
env
echo "-----------------------------------------------------------"


# PRINT ALL COMMANDS FROM HERE:
set -x


# EXPORT ENV VARIABLES FOR AWSCLI WITH HTTP PROXY IF NEEDED:
if [ -n "${HTTP_PROXY_PARAM}" ]; then
    export HTTP_PROXY="http://${HTTP_PROXY_PARAM}"
    export HTTPS_PROXY="${HTTP_PROXY}"
    export NO_PROXY="169.254.169.254,compute.internal"
fi


# ASSUME CROSS-ACCOUNT ROLE IF REQUIRED:
if [ -n "${CROSS_ACCOUNT_ROLE}" ]; then
    echo "* enabling cross-account:"
    # GET TEMPORARY CREDENTIALS FROM STS:
    set +x
    assume_role_output=$(aws sts assume-role --role-arn ${CROSS_ACCOUNT_ROLE} --role-session-name codecommit-sync --duration-seconds ${CROSS_ACCOUNT_ROLE_SESSION_DURATION})
    [[ "$?" != 0 ]] && {
        echo "ERROR: assume-role ${CROSS_ACCOUNT_ROLE}"; exit 1
    }
    export AWS_ACCESS_KEY_ID=$(echo $assume_role_output | jq -r .Credentials.AccessKeyId)
    export AWS_SECRET_ACCESS_KEY=$(echo $assume_role_output | jq -r .Credentials.SecretAccessKey)
    export AWS_SESSION_TOKEN=$(echo $assume_role_output | jq -r .Credentials.SessionToken)
    set -x
fi


# SET REGION-SPECIFIC VARIABLES:
if [ "${REGION}" == "us-east-1" ]; then
    S3_BUCKET_CONFIGURATION=""
else
    S3_BUCKET_CONFIGURATION="--create-bucket-configuration LocationConstraint=${REGION}"
fi


# SET VARIABLE FOR KOPS STATE STORE:
AWS_ACCOUNT_NUMBER="$(aws sts get-caller-identity --output text --query 'Account')"
KOPS_BUCKET_NAME="kops-${AWS_ACCOUNT_NUMBER}-${REGION}-${CLUSTER_NAME_PREFIX}"
export KOPS_STATE_STORE=s3://${KOPS_BUCKET_NAME}


# RUN DELETE ACTION IF NECESSARY:
if [ ${ACTION} == "destroy" ]; then
    echo "* Deleting cluster."
    kops delete cluster --state s3://${KOPS_BUCKET_NAME} ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX} --yes
    if [ ${SUBNETS_TAGGING} == "true" ]; then
        echo "* un-tagging K8s cluster-specific tags in subnets:"
        for s in ${AWS_SUBNETS//,/ }
        do
            aws ec2 delete-tags --resources ${s} --tags Key=kubernetes.io/cluster/${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX},Value=shared --region ${REGION}
        done
    fi
    exit $?
fi


# PREPARE SUBNETS CONFIGURATION:
IFS=', ' read -r -a AWS_AZS_ARRAY <<< "${AWS_AZS}"
declare -A AWS_NATGWS
KOPS_SUBNETS_JSON="["
AZ_ITERATOR="0"
for s in ${AWS_SUBNETS//,/ }
do
    AWS_ZONE="${AWS_AZS_ARRAY[${AZ_ITERATOR}]}"
    if [ ${DISABLE_NATGW} == "true" ]; then
        set +x
        KOPS_SUBNETS_JSON=$(cat <<EOF
        ${KOPS_SUBNETS_JSON}
        {
          "name": "${AWS_ZONE}",
          "zone": "${AWS_ZONE}",
          "id": "${s}",
          "type": "Private",
        },
        {
          "name": "utility-${AWS_ZONE}",
          "zone": "${AWS_ZONE}",
          "id": "${s}",
          "type": "Utility"
        }
EOF
        )
        set -x
    else
        ## DETECT which NATGWs are associated with subnets:
        AWS_NATGWS[${s}]=$(aws ec2 describe-route-tables --region ${REGION} --filter "Name=vpc-id, Values=${VPC_ID}" "Name=association.subnet-id, Values=${s}" | jq '.RouteTables | .[].Routes | .[].NatGatewayId | select(. != null)')
        echo "* subnet/natgw: ${s}/${AWS_NATGWS[${s}]}"
        set +x
        KOPS_SUBNETS_JSON=$(cat <<EOF
        ${KOPS_SUBNETS_JSON}
        {
          "name": "${AWS_ZONE}",
          "zone": "${AWS_ZONE}",
          "id": "${s}",
          "type": "Private",
          "egress": ${AWS_NATGWS[${s}]}
        },
        {
          "name": "utility-${AWS_ZONE}",
          "zone": "${AWS_ZONE}",
          "id": "${s}",
          "type": "Utility"
        }
EOF
        )
        set -x
    fi
    if [ ${SUBNETS_TAGGING} == "true" ]; then
        echo "* tagging subnet with K8s cluster-specific tag:"
        aws ec2 create-tags --resources ${s} --tags Key=kubernetes.io/cluster/${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX},Value=shared --region ${REGION}
    fi
    AZ_ITERATOR=$((AZ_ITERATOR + 1))
    [ ${AZ_ITERATOR} -lt ${#AWS_AZS_ARRAY[@]} ] && KOPS_SUBNETS_JSON="${KOPS_SUBNETS_JSON},"
done
KOPS_SUBNETS_JSON="${KOPS_SUBNETS_JSON}]"

set +x
echo "----------------"
echo ${KOPS_SUBNETS_JSON}
echo "----------------"
set -x
if [ ${DISABLE_NATGW} == "false" ] && [ ${#AWS_NATGWS[@]} -ne ${#AWS_AZS_ARRAY[@]} ]; then
    echo "* ERROR: invalid NAT Gateway detection."
    exit 1
fi


# CHECK IF KOPS STATE BUCKET EXISTS AND CREATE OTHERWISE, ALSO ENABLE VERSIONING:    
aws s3 ls ${KOPS_BUCKET_NAME} || aws s3api create-bucket --bucket ${KOPS_BUCKET_NAME} --region ${REGION} ${S3_BUCKET_CONFIGURATION}
aws s3api put-bucket-versioning --bucket ${KOPS_BUCKET_NAME} --versioning-configuration Status=Enabled


# CREATE SSH KEY TO ACCESS K8S INSTANCES (OPTIONALLY):
# FIXME: conditional statement disabled due to: https://github.com/kubernetes/kops/issues/4728
#if [ -z "${AWS_SSH_KEYPAIR_NAME}" ]; then
    [[ ! -f ~/.ssh/id_rsa_${CLUSTER_NAME_PREFIX} ]] && ssh-keygen -N '' -f ~/.ssh/id_rsa_${CLUSTER_NAME_PREFIX}
    OPTION_SSH_PUBLIC_KEY="--ssh-public-key ~/.ssh/id_rsa_${CLUSTER_NAME_PREFIX}.pub"
#else
#    OPTION_SSH_PUBLIC_KEY=""
#fi


# RUN KOPS BUT GENERATE CONFIGS ONLY:
rm -f ${CLUSTER_NAME_PREFIX}-kops-original.json
kops create cluster \
--vpc ${VPC_ID} \
--zones ${AWS_AZS} \
--master-zones ${AWS_AZS} \
--subnets ${AWS_SUBNETS} \
--utility-subnets ${AWS_SUBNETS} \
--node-count ${K8S_NODE_COUNT} \
--topology private \
--api-loadbalancer-type internal \
--master-size ${K8S_MASTER_INSTANCE_TYPE} \
--node-size ${K8S_NODE_INSTANCE_TYPE} \
--image amazon.com/amzn2-ami-hvm-2.0.20190115-x86_64-gp2 \
--networking calico \
${OPTION_SSH_PUBLIC_KEY} \
--name ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX} \
--cloud-labels ${TAGS} \
--dry-run --output json > ${CLUSTER_NAME_PREFIX}-kops-original.json


# MODIFY OUTPUT FILE WITH CLUSTER SPECIFICATION:
## Cluster:
CLUSTER_JQ_FILTER=".[0] | .spec.api.loadBalancer.type = \"Internal\" | .spec.subnets = ${KOPS_SUBNETS_JSON} | .spec.docker.logDriver=\"awslogs\" | .spec.docker.logOpt=[\"awslogs-region=${REGION}\", \"awslogs-group=${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX}\"]"
if [ -n "${AWS_SSH_KEYPAIR_NAME}" ]; then
  CLUSTER_JQ_FILTER="${CLUSTER_JQ_FILTER} | .spec.sshKeyName=\"${AWS_SSH_KEYPAIR_NAME}\""
fi
if [ -n "${HTTP_PROXY_PARAM}" ]; then
    echo "* Including HTTP proxy configuration for: ${HTTP_PROXY_PARAM}."
    HTTP_PROXY_HOST=$(echo ${HTTP_PROXY_PARAM} | sed -e 's/:[0-9]\+//')
    HTTP_PROXY_PORT=$(echo ${HTTP_PROXY_PARAM} | grep -o ':[0-9]\+$' | sed -e 's/://')
    CLUSTER_JQ_FILTER="${CLUSTER_JQ_FILTER} | .spec.egressProxy.httpProxy.host = \"${HTTP_PROXY_HOST}\" | .spec.egressProxy.httpProxy.port = ${HTTP_PROXY_PORT} | .spec.egressProxy.excludes = \"${HTTP_PROXY_EXCLUDES}\""
fi
cat ${CLUSTER_NAME_PREFIX}-kops-original.json | jq "${CLUSTER_JQ_FILTER}" > ${CLUSTER_NAME_PREFIX}-kops-modified-cluster.json
## InstanceGroups:
INSTANCE_GROUPS_COUNT=0
grep InstanceGroup ${CLUSTER_NAME_PREFIX}-kops-original.json | sed -e 's/^,//' | while read -r line;
do
    INSTANCE_GROUPS_COUNT=$((INSTANCE_GROUPS_COUNT + 1))
    echo ${line} > ${CLUSTER_NAME_PREFIX}-kops-original-instance-group-${INSTANCE_GROUPS_COUNT}.json
done
### workaround for above subshell execution that can't modify variables
INSTANCE_GROUPS_COUNT=$(grep InstanceGroup ${CLUSTER_NAME_PREFIX}-kops-original.json | wc -l)


# CREATE KOPS OBJECTS:
## Cluster:
kops create -f ${CLUSTER_NAME_PREFIX}-kops-modified-cluster.json ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX}
## InstanceGroups:
for i in $(seq 1 $INSTANCE_GROUPS_COUNT);
do
    JSON_FILE_INPUT="${CLUSTER_NAME_PREFIX}-kops-original-instance-group-${i}.json"
    JSON_FILE_OUTPUT="${CLUSTER_NAME_PREFIX}-kops-modified-instance-group-${i}.json"
    if grep --quiet master ${JSON_FILE_INPUT};
    then
        IG_JQ_FILTER=".spec.iam.profile = \"${K8S_MASTERS_IAM_INSTANCE_PROFILE_ARN}\""
    else
        IG_JQ_FILTER=".spec.iam.profile = \"${K8S_NODES_IAM_INSTANCE_PROFILE_ARN}\""
    fi
    cat ${JSON_FILE_INPUT} | jq "${IG_JQ_FILTER}" > ${JSON_FILE_OUTPUT}
    kops create -f ${JSON_FILE_OUTPUT} ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX}
done
## Secrets:
# FIXME: conditional statement disabled due to: https://github.com/kubernetes/kops/issues/4728
#if [ -z "${AWS_SSH_KEYPAIR_NAME}" ]; then
  kops create secret --name ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX} sshpublickey admin -i ~/.ssh/id_rsa_${CLUSTER_NAME_PREFIX}.pub
#fi


# PRINT OUT SUMMARY:
set +x
echo "-----------------------------------------------------------------------"
kops get cluster ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX}
kops get instancegroups --name ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX}
kops get secrets --name ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX}
echo "-----------------------------------------------------------------------"
echo "* Configuration ready, press Enter to launch deployment, ctrl-C to break."
read
set -x


# CREATE RESOURCES IN AWS:
KOPS_LIFECYCLE_OVERRRIDES="IAMRole=ExistsAndWarnIfChanges,IAMRolePolicy=ExistsAndWarnIfChanges,IAMInstanceProfileRole=ExistsAndWarnIfChanges"
[ "${DISABLE_NATGW}" == "true" ] && KOPS_LIFECYCLE_OVERRRIDES="${KOPS_LIFECYCLE_OVERRRIDES},InternetGateway=Ignore"
kops update cluster ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX} --yes --lifecycle-overrides ${KOPS_LIFECYCLE_OVERRRIDES}
kops rolling-update cluster ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX} --cloudonly --force --yes
set +x
echo "-----------------------------------------------------------------------"
echo "* Deployment initiated, waiting for the cluster to become operational (may take ~40 mins for 3-masters cluster)..."

while true;
do
    K8S_NUMBER_OF_HEALTHY_MASTERS="$(kubectl get nodes | grep -v NAME | grep -e master | grep -v NotReady | grep Ready | wc -l)"
    K8S_NUMBER_OF_HEALTHY_NODES="$(kubectl get nodes | grep -v NAME | grep -e node | grep -v NotReady | grep Ready | wc -l)"
    if [ "${K8S_NUMBER_OF_HEALTHY_MASTERS}" -ge "${K8S_MIN_HEALTHY_MASTERS}" ] && [ "${K8S_NUMBER_OF_HEALTHY_NODES}" -ge "${K8S_MIN_HEALTHY_NODES}" ];
    then
        kops validate cluster --state ${KOPS_STATE_STORE} ${CLUSTER_NAME_PREFIX}.${CLUSTER_NAME_POSTFIX}
        kubectl get nodes
        echo "* CLUSTER LOOKS OPERATIONAL (may still need some time to fully settle down)."
        break
    else
        sleep 30s
    fi
done
