#!/usr/bin/env bash

# Verifica che il Deployment rispetti le best practice minime:
# readinessProbe, livenessProbe, resources.requests, resources.limits.
#
# Exit code: 0 = tutti i controlli superati
#            1 = almeno un attributo mancante

set -euo pipefail

NAMESPACE=formazione-sou
DEPLOYMENT=flask-app-example
MANIFEST=./deployment-export.json

kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json > "$MANIFEST"

mancanti=$(jq -r '
    .spec.template.spec.containers[] as $c
    | [ ("readinessProbe"           | select($c.readinessProbe           == null)),
        ("livenessProbe"            | select($c.livenessProbe            == null)),
        ("resources.requests.cpu"   | select($c.resources.requests.cpu   == null)),
        ("resources.requests.memory"| select($c.resources.requests.memory== null)),
        ("resources.limits.cpu"     | select($c.resources.limits.cpu     == null)),
        ("resources.limits.memory"  | select($c.resources.limits.memory  == null)) ]
    | .[] | "\($c.name): \(.)"
' "$MANIFEST")

if [ -n "$mancanti" ]; then
    echo "MANCANTI:"
    echo "$mancanti"
    exit 1
fi

echo "OK - tutti gli attributi presenti"
