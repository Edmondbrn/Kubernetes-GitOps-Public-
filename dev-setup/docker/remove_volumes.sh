#!/bin/bash -

echo "This script will stop the running containers and remove the associated volumes, you could lose data. Be careful"
read -p "Do you want to continue (Y/n) : " res

if [ "$res" == "y" ] && [ "$res" == "Y" ]; then
    docker compose down -v
    exit 0;
else
    echo "Script execution cancelled";
fi