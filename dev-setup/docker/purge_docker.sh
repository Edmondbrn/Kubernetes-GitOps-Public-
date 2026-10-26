#!/bin/bash -

echo "This script will kill and remove all containers and docker images"
read -p "Do you want to continue (Y/n) : " res

if [ "$res" != "y" ] && [ "$res" != "Y" ]; then
    echo "Script execution cancelled";
    exit 0;
fi