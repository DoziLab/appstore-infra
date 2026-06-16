# Self-signed certificate generation
# Run this once on the server to generate the certificates:
#
#   mkdir -p /opt/appstore/nginx/certs
#   openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
#     -keyout /opt/appstore/nginx/certs/selfsigned.key \
#     -out /opt/appstore/nginx/certs/selfsigned.crt \
#     -subj "/CN=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4)"
#
# The certs/ directory is in .gitignore — certificates are never committed.
