#!/bin/bash

export apihost=127.0.0.1


# install app
curl -k -u admin https://${apihost}:8089/services/apps/local --data-binary "@rt-uf.tar.gz" -H "Content-Type: application/x-tar"


#curl -k -u admin https://${apihost}:8089/services/admin/exec/dummy -d "command=whoami"