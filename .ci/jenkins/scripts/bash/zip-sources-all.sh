#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

### MANDATORY VARIABLES DEFINITION - UNCOMMENT FOR LOCAL USE     ###
### In Jenkins these VARIABLES are set as jenkins job parameters ###

#VERSION="10.0.0"
#BRANCH_DEFAULT="main"
# Configuration in format "repository-id;repository_name;branch(if-override-needed)"
# - eg.not all repositories have main branch
#REPOS="drools-repo;incubator-kie-drools
#kogito-runtimes-repo;incubator-kie-kogito-runtimes
#kogito-apps-repo;incubator-kie-kogito-apps
#kogito-images-repo;incubator-kie-kogito-images
#optaplanner-repo;incubator-kie-optaplanner
#kogito-serverless-operator-repo;incubator-kie-kogito-serverless-operator
#optaplanner-quickstarts-repo;incubator-kie-optaplanner-quickstarts;development
#kogito-examples-repo;incubator-kie-kogito-examples
#kie-tools-repo;incubator-kie-tools
#kie-sandbox-quarkus-accelerator-repo;incubator-kie-sandbox-quarkus-accelerator
#kogito-online-repo;incubator-kie-kogito-online"

function zip_sources() {
  SOURCES_DIRECTORY_NAME="sources"
  REPO_ORGANIZATION="apache"

  while read line; do
    BRANCH=${BRANCH_DEFAULT}
    #get rid of carriage return character if present
    line="$(echo $line | sed 's#\r##g')"

    #Clone
    echo "Clone $( echo $line | awk -F';' '{ print $1 }' | sed 's\-repo\\g' )"
    REPO_NAME=$( echo $line | awk -F';' '{print $2 }' )
    REPO_DIRECTORY=${SOURCES_DIRECTORY_NAME}/${REPO_NAME}
    REPO_BRANCH=$( echo $line | awk -F';' '{print $3}' )
    if [[ ! -z ${REPO_BRANCH} ]]; then
      BRANCH=$REPO_BRANCH
    fi
    git clone --branch ${BRANCH} --depth 1 "https://github.com/${REPO_ORGANIZATION}/${REPO_NAME}.git" ${REPO_DIRECTORY}
    STATE=$?
    if [[ ${STATE} != 0 ]]; then
      echo "Clonning of ${REPO_NAME} was NOT successfull. Failing"
      exit 1
    fi

    #Remove unnecessary dirs
    pushd $REPO_DIRECTORY
    CURRENT_DIRECTORY=$(pwd)
    echo "Current directory is ${CURRENT_DIRECTORY}"
    echo "Before .git removal"
    ls -lha
    echo "Searching for .git directory"
    if [[ -d '.git' ]]; then
        echo ".git directory found, deleting..."
        rm -rf ".git"
    fi
    echo "After .git removal"
    ls -lha
    popd

    #Creating ZIP
    pushd ${SOURCES_DIRECTORY_NAME}
    ZIP_FILE_NAME="${REPO_NAME}-sources-${VERSION}.zip"
    echo "Creating ${ZIP_FILE_NAME}"
    zip -ry ${ZIP_FILE_NAME} ${REPO_NAME} # eventually we can avoid having also parent folder zipped, this way
    if [[ ! -f ${ZIP_FILE_NAME} ]]; then
      echo "${ZIP_FILE_NAME} has not been created."
      exit 2
    fi
    ls -lha ${ZIP_FILE_NAME}
    popd
    rm -rf ${REPO_DIRECTORY}

  done <<< $REPOSITORIES
}

function zip_container_sources() {
  SOURCES_DIRECTORY_NAME="container-sources"
  REPO_ORGANIZATION="apache"
  REPO_KOGITO_TOOLS="incubator-kie-tools"
  BRANCH="main"

  #Clone
  echo "Clone ${REPO_KOGITO_TOOLS}"
  REPO_DIRECTORY=${SOURCES_DIRECTORY_NAME}/${REPO_KOGITO_TOOLS}
  git clone --branch ${BRANCH} --depth 1 "https://github.com/${REPO_ORGANIZATION}/${REPO_KOGITO_TOOLS}.git" ${REPO_DIRECTORY}
  STATE=$?
  if [[ ${STATE} != 0 ]]; then
    echo "Clonning of ${REPO_KOGITO_TOOLS} was NOT successfull. Failing"
    exit 1
  fi

#Remove unnecessary dirs
  pushd ${REPO_DIRECTORY}/packages
  CURRENT_DIRECTORY=$(pwd)
  echo "Current directory is ${CURRENT_DIRECTORY}"
  echo "Before cleanup"
  ls -lha
  echo "Removing directories other than container sources"
  for filename in $PWD/*; do
    [[ $filename != *image ]] || continue
      rm -rf $filename
  done
  echo "After cleanup"
  ls -lha
  popd


  #Creating ZIP
  pushd ${SOURCES_DIRECTORY_NAME}
  ZIP_FILE_NAME="container-sources-${VERSION}.zip"
  echo "Creating ${ZIP_FILE_NAME}"
  ( cd ${REPO_KOGITO_TOOLS}/packages/ && zip -ry ../../${ZIP_FILE_NAME} * )
  if [[ ! -f ${ZIP_FILE_NAME} ]]; then
    echo "${ZIP_FILE_NAME} has not been created."
    exit 2
  fi
  ls -lha ${ZIP_FILE_NAME}
  popd
  rm -rf ${REPO_DIRECTORY}

}

zip_sources
zip_container_sources
