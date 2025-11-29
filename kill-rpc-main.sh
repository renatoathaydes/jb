#!/usr/bin/env bash

# Get all Java processes and filter for RpcMain
echo "Looking for RpcMain processes..."

# Run jps and look for RpcMain
rpc_pids=$(jps | grep "RpcMain" | awk '{print $1}')

if [ -z "$rpc_pids" ]; then
    echo "No RpcMain processes found."
    exit 0
fi

# Kill all RpcMain processes
echo "Found RpcMain process(es): $rpc_pids"
echo "Killing process(es)..."
kill $rpc_pids
if [ $? -eq 0 ]; then
    echo "Successfully killed all RpcMain processes"
else
    echo "Failed to kill one or more processes"
fi

echo "Done."

