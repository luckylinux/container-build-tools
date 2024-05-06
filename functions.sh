#!/bin/bash

# Print Debug Message if Environment DEBUG_CONTAINER is set to something
debug_message() {
   # Debug Message processes all arguments
   local lmessage="${*}"

   # Calling Stack
   #local lcallingstack=("${FUNCNAME[@]:1}")
   #local lstack="${FUNCNAME[@]}"
   local lstack="${FUNCNAME}"

   # Print Stack
   #echo "Calling Debug from <${FUNCNAME[1]}>" >&2
   #echo "Calling Stack Size: <${#FUNCNAME[@]}>" >&2

   # Check if Environment Variable is Set
   if [[ -n "${DEBUG_CONTAINER}" ]]
   then
      # Show the Debug Message
      echo "${lmessage}" >&2

      if [[ -n "${DEBUG_CONTAINER_STACK}" ]]
      then
         # Show the Debug Stack
         echo "Call Stack:" >&2

         # Show the Debug Stack
         debug_stack "${lstack}"
      fi
   fi
}


# Print Stack Size
debug_stack() {
   # Debug Stack Local Variable
   #local lstack="${*}"
   local lstack=("${FUNCNAME[@]:1}")

   # Number of Elements
   local lnum=${#lstack[@]}

   # Debug
   #echo "${FUNCNAME[0]} - Stack has <${lnum}> Elements."

   #echo "First: ${lstack[0]}"
   #echo "Second: ${lstack[1]}"
   #echo "Third: ${lstack[2]}"

   # Last Index
   local llast=$((lnum-1))

   # Iterate
   local lindex=0
   local lindent=""
   for lindex in $(seq 0 ${llast})
   do
      lindent=$(repeat_character "\t" "${lindex}")
      echo -e "${lindent} [${lindex}] ${lstack[${lindex}]}" >&2
   done
}


# Repeat Character N times
repeat_character() {
   # Character to repeat
   local lcharacter=${1}

   # Number of Repetitions
   local lrepetitions=${2}

   # Print using Brace Expansion
   #for i in {1 ... ${lrepetitions}}
   for i in $(seq 1 1 ${lrepetitions})
   do
       echo -n "${lcharacter}"
   done
}




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

   # Debug
   debug_message "${FUNCNAME[0]} - Exists Code is ${lexistscode}"

   # Check if Container is Running
   container_is_running "registry" "${lengine}"

   # Store Running Code
   lisrunningcode=$?

   # Debug
   debug_message "${FUNCNAME[0]} - Running Code is ${lisrunningcode}"

   if [[ $lexistscode -eq 0 ]]
   then
       # Container Exists
       if [[ $lisrunningcode -ne 0 ]]
       then
          # Container is NOT currently running

          # Debug
          debug_message "${FUNCNAME[0]} - Container is NOT currently running"

          # Echo
          echo "${lengine}: Run Container <registry>"

          # Run a Local Registry WITHOUT Persistent Data Storage
          # Replace the existing Container
          ${lengine} run --replace -d -p 0.0.0.0:5000:5000 --name registry registry:2
       else
          # Debug
          debug_message "${FUNCNAME[0]} - Container is already running. No need fur further Action."
       fi
   else
       # Container does NOT exist

       # Debug
       debug_message "${FUNCNAME[0]} - Container does NOT currently exist"

       # Echo
       echo "${lengine}: Run Container <registry>"

       # Start Container
       # Run a Local Registry WITHOUT Persistent Data Storage
       ${lengine} run -d -p 0.0.0.0:5000:5000 --name registry registry:2
   fi
}

