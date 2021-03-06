#!/usr/bin/env bash

# Create/manage images corresponding to the current build

[[ -n "${AUTOMATION_DEBUG}" ]] && set ${AUTOMATION_DEBUG}
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM
. "${AUTOMATION_BASE_DIR}/common.sh"

# Ensure we are in the directory where local images have been built
cd ${AUTOMATION_BUILD_DIR}

function usage() {
    cat <<EOF

Manage images corresponding to the current build

Usage: $(basename $0) -g CODE_COMMIT -u DEPLOYMENT_UNIT -f IMAGE_FORMATS

where

(m) -f IMAGE_FORMATS   is the comma separated list of image formats to manage
(m) -g CODE_COMMIT     to use when defaulting REGISTRY_REPO
(m) -u DEPLOYMENT_UNIT is the deployment unit associated with the imges

(m) mandatory, (o) optional, (d) deprecated

DEFAULTS:

DEPLOYMENT_UNIT=First entry in DEPLOYMENT_UNIT_LIST
CODE_COMMIT=First entry in CODE_COMMIT_LIST
IMAGE_FORMATS=First entry in IMAGE_FORMAT_LIST

NOTES:

EOF
    exit
}

# Parse options
while getopts ":f:g:hu:" opt; do
    case $opt in
        f)
            IMAGE_FORMATS="${OPTARG}"
            ;;
        g)
            CODE_COMMIT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        u)
            DEPLOYMENT_UNIT="${OPTARG}"
            ;;
        \?)
            fatalOption; exit
            ;;
        :)
            fatalOptionArgument; exit
            ;;
     esac
done

# Apply defaults
DEPLOYMENT_UNIT_ARRAY=(${DEPLOYMENT_UNIT_LIST})
CODE_COMMIT_ARRAY=(${CODE_COMMIT_LIST})
IMAGE_FORMATS_ARRAY=(${IMAGE_FORMATS_LIST})
DEPLOYMENT_UNIT="${DEPLOYMENT_UNIT:-${DEPLOYMENT_UNIT_ARRAY[0]}}"
CODE_COMMIT="${CODE_COMMIT:-${CODE_COMMIT_ARRAY[0]}}"
IMAGE_FORMATS="${IMAGE_FORMATS:-${IMAGE_FORMATS_ARRAY[0]}}"

# Ensure mandatory arguments have been provided
[[ (-z "${DEPLOYMENT_UNIT}") ||
    (-z "${CODE_COMMIT}") ||
    (-z "${IMAGE_FORMATS}") ]] && fatalMandatory && exit

IFS="${IMAGE_FORMAT_SEPARATORS}" read -ra FORMATS <<< "${IMAGE_FORMATS}"

for FORMAT in "${FORMATS[@]}"; do
    case ${FORMAT,,} in

        dataset)
            IMAGE_FILE="${AUTOMATION_BUILD_SRC_DIR}/cot_data_file_manifest.json"
            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageDataSetS3.sh -s \
                    -u "${DEPLOYMENT_UNIT}" \
                    -g "${CODE_COMMIT}" \
                    -f "${IMAGE_FILE}" \
                    -b "${S3_DATA_STAGE}"
                RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
            else
                RESULT=1 && fatal "${IMAGE_FILE} missing" && exit
            fi
            ;;

        rdssnapshot)
            ${AUTOMATION_DIR}/manageDataSetRDSSnapshot.sh -s \
                    -u "$DEPLOYMENT_UNIT" \
                    -g "${CODE_COMMIT}" \
                RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
            ;;

        docker)
            # Package for docker
            DOCKERFILE="${AUTOMATION_BUILD_SRC_DIR}/Dockerfile"
            if [[ -f "${AUTOMATION_BUILD_DEVOPS_DIR}/docker/Dockerfile" ]]; then
                DOCKERFILE="${AUTOMATION_BUILD_DEVOPS_DIR}/docker/Dockerfile"
            fi
            if [[ -f "${DOCKERFILE}" ]]; then
                ${AUTOMATION_DIR}/manageDocker.sh -b -s "${DEPLOYMENT_UNIT}" -g "${CODE_COMMIT}"
                RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
            else
                RESULT=1 && fatal "Dockerfile missing" && exit
            fi
            ;;

        lambda)
            IMAGE_FILE="${AUTOMATION_BUILD_SRC_DIR}/dist/lambda.zip"

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageLambda.sh -s \
                        -u "${DEPLOYMENT_UNIT}" \
                        -g "${CODE_COMMIT}" \
                        -f "${IMAGE_FILE}"
                RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
            else
                RESULT=1 && fatal "${IMAGE_FILE} missing" && exit
            fi
            ;;

        pipeline)
            IMAGE_FILE="${AUTOMATION_BUILD_SRC_DIR}/dist/pipeline.zip"

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/managePipeline.sh -s \
                        -u "${DEPLOYMENT_UNIT}" \
                        -g "${CODE_COMMIT}" \
                        -f "${IMAGE_FILE}"
                RESULT=$? && [[ "${RESULT}" -ne 0 ]]&& exit
            else
                RESULT=1 && fatal "${IMAGE_FILE} missing" && exit
            fi
            ;;

        scripts)
            IMAGE_FILE="${AUTOMATION_BUILD_SRC_DIR}/dist/scripts.zip"

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageScripts.sh -s \
                        -u "${DEPLOYMENT_UNIT}" \
                        -g "${CODE_COMMIT}" \
                        -f "${IMAGE_FILE}"
                RESULT=$? && [[ "${RESULT}" -ne 0 ]]&& exit
            else
                RESULT=1 && fatal "${IMAGE_FILE} missing" && exit
            fi
            ;;

        swagger)
            IMAGE_FILE="${AUTOMATION_BUILD_SRC_DIR}/dist/swagger.zip"

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageSwagger.sh -s \
                        -u "${DEPLOYMENT_UNIT}" \
                        -g "${CODE_COMMIT}" \
                        -f "${IMAGE_FILE}"
                RESULT=$? && [[ "${RESULT}" -ne 0 ]] && exit
            else
                RESULT=1 && fatal "${IMAGE_FILE} missing" && exit
            fi
            ;;

        spa)
            IMAGE_FILE="${AUTOMATION_BUILD_SRC_DIR}/dist/spa.zip"

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageSpa.sh -s \
                        -u "${DEPLOYMENT_UNIT}" \
                        -g "${CODE_COMMIT}" \
                        -f "${IMAGE_FILE}"
                RESULT=$? && [[ "${RESULT}" -ne 0 ]]&& exit
            else
                RESULT=1 && fatal "${IMAGE_FILE} missing" && exit
            fi
            ;;

        contentnode)
            IMAGE_FILE="${AUTOMATION_BUILD_SRC_DIR}/dist/contentnode.zip"

            if [[ -f "${IMAGE_FILE}" ]]; then
                ${AUTOMATION_DIR}/manageContentNode.sh -s \
                        -u "${DEPLOYMENT_UNIT}" \
                        -g "${CODE_COMMIT}" \
                        -f "${IMAGE_FILE}"
                RESULT=$? && [[ "${RESULT}" -ne 0 ]]&& exit
            else
                RESULT=1 && fatal "${IMAGE_FILE} missing" && exit
            fi
            ;;

        *)
            RESULT=1 && fatal "Unsupported image format \"${FORMAT}\"" && exit
            ;;
    esac
done

# All good
RESULT=0
