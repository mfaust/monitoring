#!/bin/bash
#
# part of CoreMedia Monitoring
#
# Watch logged in CM7 CMS Users

CMS_PATH="$(find /opt -type d  -name cm7-cms-tools)"
CMS_CM="${CMS_PATH}/bin/cm"

TMP_DIR="/var/cache/monitoring"
TMP_FILE="cm7_watch-users.tmp"
# -------------------------------------------------------------------------------

rm -f ${TMP_DIR}/${TMP_FILE}*

${CMS_CM} sessions -u webserver -p webserver > ${TMP_DIR}/${TMP_FILE}


cat ${TMP_DIR}/${TMP_FILE} | awk -F ', user: ' '{print $2}' | awk '{print $1}' | sort > ${TMP_DIR}/${TMP_FILE}.1

for u in feeder importer workflow publisher webserver
do
  user=$(grep -c ${u} ${TMP_DIR}/${TMP_FILE}.1)
  if [ -z ${user} ]
  then
    user=0
  fi
#  u=$(echo ${u} | sed -e 's|-|_|g' -e 's|coremedia.com|crowd|g')
  printf "\"%s\": %s," "${u}" ${user} >> ${TMP_DIR}/${TMP_FILE}.2
done

# entferne das letzte zeichen
r=$(cat ${TMP_DIR}/${TMP_FILE}.2)
r=$(echo "${r%?}")

echo "{ $r }" | json_reformat > ${TMP_DIR}/cm7-watch-users.result


# EOF