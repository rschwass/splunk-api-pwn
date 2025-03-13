

curl -k -u admin https://127.0.0.1:8089/services/apps/local/rt-win -X delete
curl -k -u admin https://127.0.0.1:8089/servicesNS/admin/search/configs/conf-restmap/exec -X delete


curl -k -u admin https://127.0.0.1:8089/services/server/control/restart -X POST