#!/bin/bash -


set -e


mkdir -p secrets/

openssl rand -base64 32 > secrets/jwt_secret_key.txt
openssl rand -base64 24 > secrets/db_user_password.txt
openssl rand -base64 24 > secrets/db_password_anon.txt
openssl rand -base64 24 > secrets/db_password_cron.txt
openssl rand -base64 24 > secrets/db_app_admin_password.txt # application admin
openssl rand -base64  8 > secrets/dba_password.txt
openssl rand -base64  8 > secrets/dav_password.txt
openssl rand -base64 24 > secrets/db_password_admin.txt # postgres admin
echo "Admin12345!" > secrets/seed_admin_password.txt

chmod 644 secrets/*.txt
cp -r secrets manifest/overlays/k3d

echo "Secrets generated"