#!/bin/bash
set -e

cd terraform

terraform destroy -auto-approve
