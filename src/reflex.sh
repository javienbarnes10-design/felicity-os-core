#!/bin/bash

# Reflex script to process and execute commands from the Sovereign Node.
function reflex {
    command="$1"
    echo "Processing command: $command" | ts '[%Y-%m-%d %H:%M:%S]' >> /Users/javienbarnes/felicity_forge/user_command.log
    eval "$command"
}

reflex "$@"
