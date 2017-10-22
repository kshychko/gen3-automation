#!/bin/bash

# Utility Functions
#
# This script is designed to be sourced into other scripts

# -- Error handling  --

function message() {
  local severity="$1"; shift
  local parts=("$@")

  echo -e "\n(${severity})" "${parts[@]}"
}

function locationMessage() {
  local parts=("$@")

  echo -n "${parts[@]}" "Are we in the right place?"
}

function cantProceedMessage() {
  local parts=("$@")

  echo -n "${parts[@]}" "Nothing to do."
}

function debug() {
  local parts=("$@")

  [[ -n "${GENERATION_DEBUG}" ]] && message "Debug" "${parts[@]}"
}

function trace() {
  local parts=("$@")

  message "Trace" "${parts[@]}"
}

function info() {
  local parts=("$@")

  message "Info" "${parts[@]}"
}

function warning() {
  local parts=("$@")

  message "Warning" "${parts[@]}"
}

function error() {
  local parts=("$@")

  message "Error" "${parts[@]}" >&2
}

function fatal() {
  local parts=("$@")

  message "Fatal" "${parts[@]}" >&2
  exit
}

function fatalOption() {
  local option="${1:-${OPTARG}}"

  fatal "Invalid option: \"-${option}\""
}

function fatalOptionArgument() {
  local option="${1:-${OPTARG}}"

  fatal "Option \"-${option}\" requires an argument"
}

function fatalCantProceed() {
  local parts=("$@")

  fatal "$(cantProceedMessage "${parts[@]}")"
}

function fatalLocation() {
  local parts=("$@")

  local restore_nullglob=$(shopt -p nullglob)
  local restore_globstar=$(shopt -p globstar)
  shopt -u nullglob globstar
  
  fatal "$(locationMessage "${parts[@]}")"

  ${restore_nullglob}
  ${restore_globstar}
}

function fatalDirectory() {
  local name="$1"; shift

  fatalLocation "We don\'t appear to be in the ${name} directory."
}

function fatalMandatory() {
  fatal "Mandatory arguments missing. Check usage via -h option."
}

# -- String manipulation --

function join() {
  local separator="$1"; shift
  local parts=("$@")

  local IFS="${separator}"
  echo -n "${parts[*]}"
}

function contains() {
  local string="$1"; shift
  local pattern="$1"; shift

  [[ "${string}" =~ ${pattern} ]]
}

# -- File manipulation --

function formatPath() {
  local parts=("$@")

  join "/" "${parts[@]}"
}

function filePath() {
  local file="$1"; shift

  echo "${file%/*}"
}

function fileName() {
  local file="$1"; shift

  echo "${file##*/}"
}

function fileBase() {
  local file="$1"; shift
  
  local name="$(fileName "${file}")"
  echo "${name%.*}"
}

function fileExtension() {
  local file="$1"; shift

  local name="$(fileName "${file}")"
  echo "${name##*.}"
}

function fileContents() {
  local file="$1"; shift

  [[ -f "${file}" ]] && cat "${file}"
}

function fileContentsInEnv() {
  local env="$1"; shift
  local files=("$@"); shift

  for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
      declare -gx ${env}="$(fileContents "${file}")"
      break
    fi
  done
}

function findAncestorDir() {
  local ancestor="$1"; shift
  local current="${1:-$(pwd)}"

  while [[ -n "${current}" ]]; do
    # Ancestor can either be a directory or a marker file
    if [[ ("$(fileName "${current}")" == "${ancestor}") ||
            ( -f "${current}/${ancestor}" ) ]]; then
      echo -n "${current}"
      return 0
    fi
    current="$(filePath "${current}")"
  done

  return 1
}

function findDir() {
  local root_dir="$1"; shift
  local patterns=("$@")

  local restore_nullglob="$(shopt -p nullglob)"
  local restore_globstar="$(shopt -p globstar)"
  shopt -s nullglob globstar  

  local matches=()
  for pattern in "${patterns[@]}"; do
    matches+=("${root_dir}"/**/${pattern})
  done

  ${restore_nullglob}
  ${restore_globstar}

  for match in "${matches[@]}"; do
    [[ -f "${match}" ]] && echo -n "$(filePath "${match}")" && return 0
    [[ -d "${match}" ]] && echo -n "${match}" && return 0
  done

  return 1
}

function findFile() {

  local restore_nullglob="$(shopt -p nullglob)"
  local restore_globstar="$(shopt -p globstar)"
  shopt -s nullglob globstar

  local matches=("$@")

  ${restore_nullglob}
  ${restore_globstar}

  for match in "${matches[@]}"; do
    [[ -f "${match}" ]] && echo -n "${match}" && return 0
  done

  return 1
}

function cleanup() {
  local root_dir="${1:-.}"

  find "${root_dir}" -name "composite_*" -delete
  find "${root_dir}" -name "STATUS.txt" -delete
  find "${root_dir}" -name "stripped_*" -delete
  find "${root_dir}" -name "ciphertext*" -delete
  find "${root_dir}" -name "temp_*" -type f -delete

  # Handle cleanup of temporary directories
  temp_dirs=($(find "${root_dir}" -name "temp_*" -type d))
  for temp_dir in "${temp_dirs[@]}"; do
    # Subdir may already have been deleted by parent temporary directory
    if [[ -e "${temp_dir}" ]]; then
      rm -rf "${temp_dir}"
    fi
  done
}

# -- Array manipulation --

function inArray() {
  local -n array="$1"; shift
  local pattern="$1"

  contains "${array[*]}" "${pattern}"
}

function arraySize() {
  local -n array="$1"; shift

  echo -n "${#array[@]}"
}

function arrayIsEmpty() {
  local array="$1"; shift

  [[ $(arraySize "${array}") -eq 0 ]]
}

function reverseArray() {
  local -n array="$1"; shift
  local target="$1"; shift

  [[ -n "${target}" ]] && local -n result="${target}" || local result=() 

  result=()
  for (( index=${#array[@]}-1 ; index>=0 ; index-- )) ; do
    result+=("${array[index]}")
  done
  
  [[ -z "${target}" ]] && array=("${result[@]}")
}

function addToArrayWithPrefix() {
  local -n array="$1"; shift
  local prefix="$1"; shift
  local elements=("$@")

  for element in "${elements[@]}"; do
    if [[ -n "${element}" ]]; then
      array+=("${prefix}${element}")
    fi
  done
}

function addToArray() {
  local array="$1"; shift
  local elements=("$@")

  addToArrayWithPrefix "${array}" "" "${elements[@]}"
}

function addToArrayHeadWithPrefix() {
  local -n array="$1"; shift
  local prefix="$1"; shift
  local elements=("$@")

  for element in "${elements[@]}"; do
    if [[ -n "${element}" ]]; then
      array=("${prefix}${element}" "${array[@]}")
    fi
  done
}

function addToArrayHead() {
  local array="$1"; shift
  local elements=("$@")

  addToArrayHeadWithPrefix "${array}" "" "${elements[@]}"
}

# -- JSON manipulation --

function runJQ() {
  local arguments=("$@")
  
  # TODO(mfl): remove once path length limitations in jq are fixed
  local tmpdir="./temp_jq_${RANDOM}"
  local modified_arguments=()
  local index=0

  mkdir -p "${tmpdir}"
  for argument in "${arguments[@]}"; do
    if [[ -f "${argument}" ]]; then
      local file="${tmpdir}/temp_${index}"
      cp "${argument}" "${file}" > /dev/null
      modified_arguments+=("${file}")
    else
      modified_arguments+=("${argument}")
    fi
    ((index++))
  done

  # TODO(mfl): Add -L once path length limitations fixed
  jq "${modified_arguments[@]}"
}

function getJSONValue() {
  local file="$1"; shift
  local patterns=("$@")
  
  local value=""

  for pattern in "${patterns[@]}"; do
    value="$(runJQ -r "${pattern} | select (.!=null)" < "${file}")"
    [[ -n "${value}" ]] && echo -n "${value}" && return 0
  done

  return 1
}

function addJSONAncestorObjects() {
  local file="$1"; shift
  local ancestors=("$@")

  # Reverse the order of the ancestors
  local pattern="."
  
  for (( index=${#ancestors[@]}-1 ; index >= 0 ; index-- )) ; do
    pattern="{\"${ancestors[index]}\" : ${pattern} }"
  done

  runJQ "${pattern}" < "${file}"
}

# -- S3 --

function isBucketAccessible() {
  local region="$1"; shift
  local bucket="$1"; shift
  local prefix="$1"; shift

  aws --region ${region} s3 ls "s3://${bucket}/${prefix}${prefix:+/}" > temp_bucket_access.txt
  return $?
}

function syncFilesToBucket() {
  local region="$1"; shift
  local bucket="$1"; shift
  local prefix="$1"; shift
  local -n files="$1"; shift
  local optional_arguments=("$@")

  local tmpdir="./temp_copyfiles"
  
  rm -rf "${tmpdir}"
  mkdir -p "${tmpdir}"
  
  # Copy files locally so we can synch with S3, potentially including deletes
  for file in "${files[@]}" ; do
    if [[ -n "${file}" ]]; then
      case "$(fileExtension "${file}")" in
        zip)
          unzip "${file}" -d "${tmpdir}"
          ;;
        *)
          cp "${file}" "${tmpdir}"
          ;;
      esac
    fi
  done
  
  # Now synch with s3
  aws --region ${region} s3 sync "${optional_arguments[@]}" "${tmpdir}/" "s3://${bucket}/${prefix}${prefix:+/}"
}

function deleteTreeFromBucket() {
  local region="$1"; shift
  local bucket="$1"; shift
  local prefix="$1"; shift
  local optional_arguments=("$@")

  # Delete everything below the prefix
  aws --region ${region} s3 rm "${optional_arguments[@]}" --recursive "s3://${bucket}/${prefix}/"
}
