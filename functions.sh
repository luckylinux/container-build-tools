#!/bin/bash

engine_exists() {
    local lengine=$1

    if [[ -z "${lengine}" ]]
    then
       echo "Container Engine cannot be Empty !"
       echo "ABORTING"
       return 9
    fi

    # Predeclare variable
    local lenginefound=""

    # Check if Engine Exists
    # Prefer Podman over Docker
    if [[ -n $(command -v podman) ]] && [[ "${engine}" == "podman" ]]
    then
        # Podman was found
        lenginefound=true

        # Return OK (Status Code 0)
        return 0
    elif [[ -n $(command -v docker) ]] && [[ "${engine}" == "docker" ]]
    then
        # Docker was found
        lenginefound=true

        # Return OK (Status Code 0)
        return 0
    else
        # Error
        lenginefound=false
        echo "[CRITICAL] Neither Podman nor Docker could be found and/or the specified Engine <$engine> was not valid."
        echo "ABORTING !"
        return 1
    fi
}

container_exists() {
   # Input Parameters
   local lcontainer=${1}
   local lengine=${2}

   # Declare Variable
   local lexistscode=9

   # Check if Container Exists
   "${lengine}" container exists "${lcontainer}"

   # Store Exists Code
   lexistscode=$?

   # Check Exit Code
   if [[ $lexistscode -eq 0 ]]
   then
      # Container exists
      return 0
   else
      # Container does NOT exist
      return $lexistscode
   fi
}

container_is_running() {
   # Input Parameters
   local lcontainer=${1}
   local lengine=${2}

   # Declare Variable
   local lexistscode=9

   # Check if Container Exists first of All
   container_exists "${lcontainer}" "${lengine}"

   # Store Exists Code
   lexistscode=$?

   # If Container Exists, check Status
   if [[ $lexistscode -eq 0 ]]
   then
      # Get Status of Container
      local lcontainerstatus=$(podman ps --all --format="{{.State}}" --filter name=^${lcontainer}\$)

      # If it's running then Return OK Exit Code
      if [[ "${lcontainerstatus}" == "running" ]]
      then
         # Container is running
         return 0
      else
         # Container is NOT running
         return 9
      fi
   else
      # Return Exit Code of Exists Function
      return $lexistscode
   fi
}

remove_image_already_present() {
    local limagetag=${1}
    local lengine=${2-"podman"}

    if [[ -z "${limagetag}" ]]
    then
       echo "Image Name:Tag cannot be Empty !"
       echo "ABORTING"
       return 9
    fi

    # Declare Variables
    local limageid

    # Check if Image Exists
    ${engine} image exists ${limagetag}
    if [[ $? -eq 0 ]]
    then
       # Ask user whether to delete existing Image
       read -p "Image <${limagetag}> already exists. Do you want to remove it and build from scratch [yes/no] -> " rebuildimage
       if [[ "${rebuildimage}" == "yes" ]]
       then
          # Get Image ID based on name:tag
          local limageid=$(${engine} images -qa --filter "reference=${limagetag}" | head -1)

          # Remove all Images
          ${engine} rmi -f ${limageid}

          # Delete Remote Images
          # This requires Skopeo
          # Many Registries do not support <delete> Commands
          # Keep it disabled
          # skopeo delete --tls-verify=false docker://localhost:5000/local/${limagetag}
       fi
    fi

}

run_local_registry() {
   local lengine=${1-"podman"}

   # Declare Variable
   local lexistscode=9
   local lisrunningcode=9

   # Check if Container Already Exists
   container_exists "registry" "${lengine}"

   # Store Exists Code
   lexistscode=$?

   # Check if Container is Running
   container_is_running "registry" "${lengine}"

   # Store Running Code
   lisrunningcode=$?

   if [[ $lexistscode -ne 0 ]]
   then
       if [[ $lisrunningcode -ne 0 ]]
       then
          # Run a Local Registry WITHOUT Persistent Data Storage
          ${lengine} run -d -p 5000:5000 --name registry registry:2
       fi
   fi
}

