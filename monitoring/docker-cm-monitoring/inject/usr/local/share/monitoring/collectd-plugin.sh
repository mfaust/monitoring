#!/bin/bash
#
# collectd plugin for Coremedia-Services
#
# Bodo Schulz
#
# 2015-06-05
# 2016-03-20
# 2016-03-22

# -------------------------------------------------------------------------------------------------

SCRIPTNAME=$(basename $0 .sh)
VERSION="2.10.2"
VDATE="20.02.2016"

# -------------------------------------------------------------------------------------------------

JOLOKIA_RC="/etc/jolokia.rc"

[ -f "${JOLOKIA_RC}" ] && {
  . ${JOLOKIA_RC}
} || {
  echo "${JOLOKIA_RC} missing"
  exit 1
}

HOSTNAME="${COLLECTD_HOSTNAME:-$(hostname -s)}"
INTERVAL="${COLLECTD_INTERVAL:-45}"

# -------------------------------------------------------------------------------------------------

readCacheDir() {

  if [ ! -f ${JOLOKIA_PORT_CACHE} ]
  then
    echo "no ports cache found"
    exit 2
  else
    filemtime=$(stat -c %Y ${JOLOKIA_PORT_CACHE})
    currtime=$(date +%s)
    diff=$(( (currtime - filemtime) / 30 ))
#        echo " .. ${filemtime} / ${currtime} : ${diff}"
    if [ ${diff} -gt 30 ]
    then
      echo "port cache ist older than 30 minutes"
    fi
  fi

  . ${JOLOKIA_PORT_CACHE}

  exit 1
}

# -------------------------------------------------------------------------------------------------

collectdPlugin_CMSUser() {

  if [[ ${HOSTNAME} =~ .*cms.* ]] # dmz-cm-cms-prod-01-vi
  then
    if [ -f ${TMP_DIR}/cm7mon_watch-users.result ]
    then

      for u in feeder importer kea_service publisher video_service webserver active_directory
      do
        user=$(jq ".${u}" ${TMP_DIR}/cm7mon_watch-users.result)

        echo "PUTVAL ${HOSTNAME}/cms-users/cm7_counter-${u} interval=${INTERVAL} N:${user}"
      done
    fi
  fi
}

collectdPlugin_Memory() {

  local result="${1}"

  local HeapMemUsed="$(cat ${result} | jq '.value.HeapMemoryUsage.used')"
  local HeapMemMax="$(cat ${result}  | jq '.value.HeapMemoryUsage.max')"

  echo "PUTVAL ${HOSTNAME}/${service}-heap_memory/cm7_counter-max interval=${INTERVAL} N:${HeapMemMax}"
  echo "PUTVAL ${HOSTNAME}/${service}-heap_memory/cm7_counter-used interval=${INTERVAL} N:${HeapMemUsed}"
}

  collectdPlugin_ClassLoading() {

  local result="${1}"

  local loadedClass="$(cat ${result} | jq '.value.LoadedClassCount')"
  local totalLoadedClass="$(cat ${result} | jq '.value.TotalLoadedClassCount')"
  local unloadedClass="$(cat ${result} | jq '.value.UnloadedClassCount')"

  echo "PUTVAL ${HOSTNAME}/${service}-class_loaded/cm7_counter-loaded interval=${INTERVAL} N:${loadedClass}"
  echo "PUTVAL ${HOSTNAME}/${service}-class_loaded/cm7_counter-total interval=${INTERVAL} N:${totalLoadedClass}"
  echo "PUTVAL ${HOSTNAME}/${service}-class_loaded/cm7_counter-unloaded interval=${INTERVAL} N:${unloadedClass}"
}

collectdPlugin_GarbageCollector() {

  local result="${1}"

  local duration="$(cat ${result}       | jq '.value.LastGcInfo.duration')"
  local beforeCCused="$(cat ${result}   | jq -r '.value.LastGcInfo.memoryUsageBeforeGc' | jq '.["Code Cache"].used')"
  local beforeCCmax="$(cat ${result}    | jq -r '.value.LastGcInfo.memoryUsageBeforeGc' | jq '.["Code Cache"].max')"
  local beforeCCinit="$(cat ${result}   | jq -r '.value.LastGcInfo.memoryUsageBeforeGc' | jq '.["Code Cache"].init')"
  local beforeCCcommit="$(cat ${result} | jq -r '.value.LastGcInfo.memoryUsageBeforeGc' | jq '.["Code Cache"].committed')"

  local afterCCused="$(cat ${result}   | jq -r '.value.LastGcInfo.memoryUsageAfterGc' | jq '.["Code Cache"].used')"
  local afterCCmax="$(cat ${result}    | jq -r '.value.LastGcInfo.memoryUsageAfterGc' | jq '.["Code Cache"].max')"
  local afterCCinit="$(cat ${result}   | jq -r '.value.LastGcInfo.memoryUsageAfterGc' | jq '.["Code Cache"].init')"
  local afterCCcommit="$(cat ${result} | jq -r '.value.LastGcInfo.memoryUsageAfterGc' | jq '.["Code Cache"].committed')"


  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector/cm7_counter-duration interval=${INTERVAL} N:${duration}"

  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector_before/cm7_counter-used interval=${INTERVAL} N:${beforeCCused}"
  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector_before/cm7_counter-max interval=${INTERVAL} N:${beforeCCmax}"
  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector_before/cm7_counter-init interval=${INTERVAL} N:${beforeCCinit}"
  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector_before/cm7_counter-commit interval=${INTERVAL} N:${beforeCCcommit}"

  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector_after/cm7_counter-used interval=${INTERVAL} N:${afterCCused}"
  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector_after/cm7_counter-max interval=${INTERVAL} N:${afterCCmax}"
  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector_after/cm7_counter-init interval=${INTERVAL} N:${afterCCinit}"
  echo "PUTVAL ${HOSTNAME}/${service}-garbage_collector_after/cm7_counter-commit interval=${INTERVAL} N:${afterCCcommit}"
}

collectdPlugin_Threading(){

  local result="${1}"

  local peak="$(cat ${result}       | jq '.value.PeakThreadCount')"
  local count="$(cat ${result}      | jq '.value.ThreadCount')"

  echo "PUTVAL ${HOSTNAME}/${service}-threading/cm7_counter-peak interval=${INTERVAL} N:${peak}"
  echo "PUTVAL ${HOSTNAME}/${service}-threading/cm7_counter-count interval=${INTERVAL} N:${count}"
}

collectdPlugin_CMCAECacheContentBeans() {

  local result="${1}"

  local capacity=$(cat ${result} | jq '.value.Capacity')
  local evaluated=$(cat ${result} | jq '.value.Evaluated')
  local evicted=$(cat ${result} | jq '.value.Evicted')
  local inserted=$(cat ${result} | jq '.value.Inserted')
  local removed=$(cat ${result} | jq '.value.Removed')
  local level=$(cat ${result} | jq '.value.Level')

  echo "PUTVAL ${HOSTNAME}/${service}-content_beans/cm7_counter-level interval=${INTERVAL} N:${level}"
  echo "PUTVAL ${HOSTNAME}/${service}-content_beans/cm7_counter-capacity interval=${INTERVAL} N:${capacity}"
  echo "PUTVAL ${HOSTNAME}/${service}-content_beans/cm7_counter-evaluated interval=${INTERVAL} N:${evaluated}"
  echo "PUTVAL ${HOSTNAME}/${service}-content_beans/cm7_counter-evicted interval=${INTERVAL} N:${evicted}"
  echo "PUTVAL ${HOSTNAME}/${service}-content_beans/cm7_counter-inserted interval=${INTERVAL} N:${inserted}"
  echo "PUTVAL ${HOSTNAME}/${service}-content_beans/cm7_counter-removed interval=${INTERVAL} N:${removed}"
}

collectdPlugin_CMCAEBlobCache() {

  local result="${1}"

  local blobCacheSize=$(cat ${result} | jq '.value.BlobCacheSize')
  local blobCacheLevel=$(cat ${result} | jq '.value.BlobCacheLevel')
  local blobCacheFaults=$(cat ${result} | jq '.value.BlobCacheFaults')

  local heapCacheSize=$(cat ${result} | jq '.value.HeapCacheSize')
  local heapCacheLevel=$(cat ${result} | jq '.value.HeapCacheLevel')
  local heapCacheFaults=$(cat ${result} | jq '.value.HeapCacheFaults')

  echo "PUTVAL $HOSTNAME/${service}-blob_cache/cm7_counter-size interval=$INTERVAL N:${blobCacheSize}"
  echo "PUTVAL $HOSTNAME/${service}-blob_cache/cm7_counter-level interval=$INTERVAL N:${blobCacheLevel}"
  echo "PUTVAL $HOSTNAME/${service}-blob_cache/cm7_counter-fault interval=$INTERVAL N:${blobCacheFaults}"

  echo "PUTVAL $HOSTNAME/${service}-heap_cache/cm7_counter-size interval=$INTERVAL N:${heapCacheSize}"
  echo "PUTVAL $HOSTNAME/${service}-heap_cache/cm7_counter-level interval=$INTERVAL N:${heapCacheLevel}"
  echo "PUTVAL $HOSTNAME/${service}-heap_cache/cm7_counter-fault interval=$INTERVAL N:${heapCacheFaults}"
}

collectdPlugin_CMCAEFeederProactiveEngine() {

  local result="${1}"

# Healthy      = feeder feels god or not so fine
# KeysCount    = Max Feeder Entries
# ValuesCount  = Current Feeder Entries

  local KeysCount="$(cat ${result} | jq '.value.KeysCount' )"
  local ValuesCount="$(cat ${result} | jq '.value.ValuesCount' )"
  local CountDiff=

  [ "${KeysCount}" = "null" ]               && KeysCount=0
  [ "${ValuesCount}" = "null" ]             && ValuesCount=0

  if ( [ ${ValuesCount} -gt 0 ] && [ ${KeysCount} -gt 0 ] )
  then
    CountDiff=$(echo "${KeysCount}-${ValuesCount}" | bc)

    echo "PUTVAL $HOSTNAME/${service}-feeder/cm7_counter-max interval=$INTERVAL N:${KeysCount}"
    echo "PUTVAL $HOSTNAME/${service}-feeder/cm7_counter-current interval=$INTERVAL N:${ValuesCount}"
    echo "PUTVAL $HOSTNAME/${service}-feeder/cm7_counter-diff interval=$INTERVAL N:${CountDiff}"
  else
    echo "PUTNOTIF $HOSTNAME/${service}-feeder/cm7_counter-max message='N/A'"
    echo "PUTNOTIF $HOSTNAME/${service}-feeder/cm7_counter-current message='N/A'"
    echo "PUTNOTIF $HOSTNAME/${service}-feeder/cm7_counter-diff message='N/A'"
  fi

}

collectdPlugin_CMContentFeeder() {

  local result="${1}"

  # CurrentPendingDocuments = Returns the number of documents in the currently feeded folder to re-index after rights rule changes.
  # IndexDocuments          = Returns the number of persisted documents in the last interval.
  # IndexContentDocuments   = Number of successfully indexed content documents
  # PendingEvents           = Number of events behind most recent event
  # PendingFolders          = Returns the ids of all pending folders to re-index after rights rule changes.

#  echo "PUTVAL ${HOSTNAME}/${service}-feeder/cm7_counter-pending_folders interval=${INTERVAL} N:$(jq '.value.PendingFolders' ${result})"
  echo "PUTVAL ${HOSTNAME}/${service}-feeder/cm7_counter-pending_events interval=${INTERVAL} N:$(jq '.value.PendingEvents' ${result})"
  echo "PUTVAL ${HOSTNAME}/${service}-feeder/cm7_counter-index_documents interval=${INTERVAL} N:$(jq '.value.IndexDocuments' ${result})"
  echo "PUTVAL ${HOSTNAME}/${service}-feeder/cm7_counter-index_content_documents interval=${INTERVAL} N:$(jq '.value.IndexContentDocuments' ${result})"
  echo "PUTVAL ${HOSTNAME}/${service}-feeder/cm7_counter-current_pending_documents interval=${INTERVAL} N:$(jq '.value.CurrentPendingDocuments' ${result})"
}

collectdPlugin_CMConnectionPool() {

  local result="${1}"

  local busy="$(cat ${result} | jq '.value.BusyConnections' )"
  local idle="$(cat ${result} | jq '.value.IdleConnections' )"
  local max="$(cat ${result} | jq '.value.MaxConnections' )"
  local min="$(cat ${result} | jq '.value.MinConnections' )"
  local open="$(cat ${result} | jq '.value.OpenConnections' )"

  echo "PUTVAL $HOSTNAME/${service}-connection_pool/cm7_counter-busy interval=$INTERVAL N:${busy}"
  echo "PUTVAL $HOSTNAME/${service}-connection_pool/cm7_counter-idle interval=$INTERVAL N:${idle}"
  echo "PUTVAL $HOSTNAME/${service}-connection_pool/cm7_counter-max interval=$INTERVAL N:${max}"
  echo "PUTVAL $HOSTNAME/${service}-connection_pool/cm7_counter-min interval=$INTERVAL N:${min}"
  echo "PUTVAL $HOSTNAME/${service}-connection_pool/cm7_counter-open interval=$INTERVAL N:${open}"
}

collectdPlugin_CMQueryPool() {

  local result="${1}"

  local busy="$(jq '.value.IdleExecutors' ${result})"
  local running="$(jq '.value.RunningExecutors' ${result})"
  local max="$(jq '.value.MaxQueries' ${result})"
  local waiting="$(jq '.value.WaitingQueries' ${result})"

  echo "PUTVAL $HOSTNAME/${service}-query_pool/cm7_counter-executors-busy interval=$INTERVAL N:${busy}"
  echo "PUTVAL $HOSTNAME/${service}-query_pool/cm7_counter-executors-running interval=$INTERVAL N:${running}"
  echo "PUTVAL $HOSTNAME/${service}-query_pool/cm7_counter-queries-max interval=$INTERVAL N:${max}"
  echo "PUTVAL $HOSTNAME/${service}-query_pool/cm7_counter-queries-wainting interval=$INTERVAL N:${waiting}"
}

collectdPlugin_CMStatisticsJobResult() {

  local result="${1}"

  local failed="$(cat ${result} | jq '.value.Failed' )"
  local success="$(cat ${result} | jq '.value.Successful' )"
  local unrecover="$(cat ${result} | jq '.value.Unrecoverable' )"

  echo "PUTVAL $HOSTNAME/${service}-stats_jobresult/cm7_counter-failed interval=$INTERVAL N:${failed}"
  echo "PUTVAL $HOSTNAME/${service}-stats_jobresult/cm7_counter-success interval=$INTERVAL N:${success}"
  echo "PUTVAL $HOSTNAME/${service}-stats_jobresult/cm7_counter-unrecover interval=$INTERVAL N:${unrecover}"
}

collectdPlugin_CMStatisticsRepository() {

  local result="${1}"

  local document_creations_avg="$(cat ${result}       | jq '.value.DocumentCreations_avg' )"
  local document_creations_samples="$(cat ${result}   | jq '.value.DocumentCreations_samples' )"
  local document_creations_sum="$(cat ${result}       | jq '.value.DocumentCreations_sum' )"
  local document_rightchecks_avg="$(cat ${result}     | jq '.value.DocumentRightsChecks_avg' )"
  local document_rightchecks_samples="$(cat ${result} | jq '.value.DocumentRightsChecks_samples' )"
  local document_rightchecks_sum="$(cat ${result}     | jq '.value.DocumentRightsChecks_sum' )"

  local folder_creations_avg="$(cat ${result}         | jq '.value.FolderCreations_avg' )"
  local folder_creations_samples="$(cat ${result}     | jq '.value.FolderCreations_samples' )"
  local folder_creations_sum="$(cat ${result}         | jq '.value.FolderCreations_sum' )"
  local folder_rightchecks_avg="$(cat ${result}       | jq '.value.FolderRightsChecks_avg' )"
  local folder_rightchecks_samples="$(cat ${result}   | jq '.value.FolderRightsChecks_samples' )"
  local folder_rightchecks_sum="$(cat ${result}       | jq '.value.FolderRightsChecks_sum' )"

  local version_creations_avg="$(cat ${result}        | jq '.value.VersionCreations_avg' )"
  local version_creations_samples="$(cat ${result}    | jq '.value.VersionCreations_samples' )"
  local version_creations_sum="$(cat ${result}        | jq '.value.VersionCreations_sum' )"

  echo "PUTVAL $HOSTNAME/${service}-stats_repository_document_creation/cm7_counter-avg interval=$INTERVAL N:${document_creations_avg}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_document_creation/cm7_counter-samples interval=$INTERVAL N:${document_creations_samples}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_document_creation/cm7_counter-sum interval=$INTERVAL N:${document_creations_sum}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_document_rightchecks/cm7_counter-avg interval=$INTERVAL N:${document_rightchecks_avg}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_document_rightchecks/cm7_counter-samples interval=$INTERVAL N:${document_rightchecks_samples}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_document_rightchecks/cm7_counter-sum interval=$INTERVAL N:${document_rightchecks_sum}"

  echo "PUTVAL $HOSTNAME/${service}-stats_repository_folder_creation/cm7_counter-avg interval=$INTERVAL N:${folder_creations_avg}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_folder_creation/cm7_counter-samples interval=$INTERVAL N:${folder_creations_samples}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_folder_creation/cm7_counter-sum interval=$INTERVAL N:${folder_rightchecks_sum}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_folder_rightchecks_avg/cm7_counter-avg interval=$INTERVAL N:${folder_rightchecks_avg}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_folder_rightchecks_samples/cm7_counter-samples interval=$INTERVAL N:${folder_rightchecks_samples}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_folder_rightchecks_sum/cm7_counter-sum interval=$INTERVAL N:${folder_rightchecks_sum}"

  echo "PUTVAL $HOSTNAME/${service}-stats_repository_version_creation/cm7_counter-avg interval=$INTERVAL N:${version_creations_avg}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_version_creation/cm7_counter-samples interval=$INTERVAL N:${version_creations_samples}"
  echo "PUTVAL $HOSTNAME/${service}-stats_repository_version_creation/cm7_counter-sum interval=$INTERVAL N:${version_creations_sum}"
}

collectdPlugin_CMRLSReplicator() {

  local result="${1}"
  local port="${2}"

#   BASE_ISN=  # "$(curl --silent http://${BASE_RLS}:8000/${port}/CMRLSReplicator.result | jq '.value.LatestIncomingSequenceNumber')"
#   BASE_CSN=  # "$(curl --silent http://${BASE_RLS}:8000/${port}/CMRLSReplicator.result | jq '.value.LatestCompletedSequenceNumber')"
  local_ISN="$(jq '.value.LatestIncomingSequenceNumber' ${result})"
  local_CSN="$(jq '.value.LatestCompletedSequenceNumber' ${result})"

#   [ "${BASE_ISN}" = "null" ]   && BASE_ISN=
#   [ "${BASE_CSN}" = "null" ]   && BASE_CSN=
  [ "${local_ISN}" = "null" ]  && local_ISN=
  [ "${local_CSN}" = "null" ]  && local_CSN=

#  echo "PUTVAL $HOSTNAME/${service}-incoming_sequence_number/cm7_counter-reference interval=$INTERVAL N:${BASE_ISN}"
  echo "PUTVAL $HOSTNAME/${service}-incoming_sequence_number/cm7_counter-local interval=$INTERVAL N:${local_ISN}"
#  echo "PUTVAL $HOSTNAME/${service}-completed_sequence_number/cm7_counter-reference interval=$INTERVAL N:${BASE_CSN}"
  echo "PUTVAL $HOSTNAME/${service}-completed_sequence_number/cm7_counter-local interval=$INTERVAL N:${local_CSN}"

#   if ( [ ! -z ${BASE_ISN} ] && [ ! -z ${local_ISN} ] )
#   then
#     diff="$(echo ${local_ISN} - ${BASE_ISN} | bc)"
#     echo "PUTVAL $HOSTNAME/${service}-incoming_sequence_number/cm7_counter-diff interval=$INTERVAL N:${diff}"
#   else
#     echo "PUTNOTIF $HOSTNAME/${service}-incoming_sequence_number/cm7_counter-diff message='N/A'"
#   fi
#
#   if ( [ ! -z ${BASE_CSN} ] && [ ! -z ${local_CSN} ] )
#   then
#     diff="$(echo ${local_CSN} - ${BASE_CSN} | bc)"
#     echo "PUTVAL $HOSTNAME/${service}-completed_sequence_number/cm7_counter-diff interval=$INTERVAL N:${diff}"
#   else
#     echo "PUTNOTIF $HOSTNAME/${service}-completed_sequence_number/cm7_counter-diff message='N/A'"
#   fi

}

collectdPlugin_CMFeederReplicator() {

  local result="${1}"
#   local port="48099"

  BASE_CSN=0 #"$(curl --silent http://${BASE_RLS}:8000/${port}/CMRLSReplicator.result | jq '.value.LatestCompletedSequenceNumber')"
  local_PSN="$(jq '.value.LastProcessedTimestamp' ${result} | sed 's|"||g' | awk -F':' '{print $1}')"
  local_CSN="$(jq '.value.LatestCompletedSequenceNumber' ${result})"

  echo "PUTVAL $HOSTNAME/${service}-completed_sequence_number/cm7_counter-reference interval=$INTERVAL N:${BASE_CSN}"
  echo "PUTVAL $HOSTNAME/${service}-processed_sequence_number/cm7_counter-local interval=$INTERVAL N:${local_PSN}"

#   if ( [ ! -z ${BASE_CSN} ] && [ ! -z ${local_PSN} ] )
#   then
#     diff="$(echo ${local_PSN} - ${BASE_CSN} | bc)"
#     echo "PUTVAL $HOSTNAME/${service}-processed_sequence_number/cm7_counter-diff interval=$INTERVAL N:${diff}"
#   fi

}

collectdPlugin_Solr() {

  local result="${1}"
  local port="${2}"

  ENV="prod"
  CORE="live"

#   if [[ ${HOSTNAME} =~ .*prod.* ]]
#   then
#     # LIVE
#     ENV="prod"
#   else
#     ENV="stage"
#   fi
#
#   if [[ ${HOSTNAME} =~ ^web.* ]]
#   then
#     # LIVE
#     CORE="live"
#   elif [[ ${HOSTNAME} =~ ^dmz.* ]]
#   then
#     CORE="preview"
#   fi

#   file="${TMP_DIR}/${port}/solr.${CORE}.result"

#   echo " ==> $result"
#   echo " ==> $port"
#   echo " ==> $file"

  if [ -f "${result}" ]
  then
#    result="${TMP_DIR}/${port}/solr.${CORE}.result"

#    SOLR_MASTER="cmstr-${ENV}-rls-01.svc.guj.de"
#    SOLR_MASTER="cmstr-${ENV}-${CORE}-feeder.svc.guj.de"
    RESULT_FILE="$(basename ${result})" ###   sed -e "s|${TMP_DIR}/${port}/||g")" ###  solr.${CORE}.result"

    if [[ ${RESULT_FILE} =~ ^SolrReplicationHandler.*result ]]
#    if ( [ "${result}" = "solr.live.result" ] || [ "${result}" = "solr.preview.result" ] || [ "${result}" = "solr.studio.result" ] )
    then
      core="$(echo "${RESULT_FILE}" | sed -e 's|SolrReplicationHandler.||g' -e 's|.result||g')"
      SOLR_MASTER_PORT="44099"
      SOLR_SLAVE_PORT="45099"

      local masterIndex=        #"$(curl --silent http://${SOLR_MASTER}:8000/${SOLR_MASTER_PORT}/${RESULT_FILE} | jq '.details.indexVersion')"
      local masterGeneration=   # "$(curl --silent http://${SOLR_MASTER}:8000/${SOLR_MASTER_PORT}/${RESULT_FILE} | jq '.details.generation')"
      local localIndex="$(jq '.details.indexVersion' ${result})"
      local localGeneration="$(jq '.details.generation' ${result})"

      [ "${masterIndex}" = "null" ]       && masterIndex=
      [ "${masterGeneration}" = "null" ]  && masterGeneration=
      [ "${localIndex}" = "null" ]        && localIndex=
      [ "${localGeneration}" = "null" ]   && localGeneration=

      echo "PUTVAL ${HOSTNAME}/${service}-${core}_core/cm7_counter-index interval=$INTERVAL N:${localIndex}"
      echo "PUTVAL ${HOSTNAME}/${service}-${core}_core/cm7_counter-generation interval=$INTERVAL N:${localGeneration}"

      if ( [ ! -z ${masterIndex} ] && [ ! -z ${localIndex} ] )
      then
        diff="$(echo ${localIndex} - ${masterIndex} | bc)"
        echo "PUTVAL $HOSTNAME/${service}-${core}_core/cm7_counter-index_diff interval=$INTERVAL N:${diff}"
      else
        echo "PUTNOTIF $HOSTNAME/${service}-${core}_core/cm7_counter-index_diff message='N/A'"
      fi
      if ( [ ! -z ${masterGeneration} ] && [ ! -z ${localGeneration} ] )
      then
        diff="$(echo ${localGeneration} - ${masterGeneration} | bc)"
        echo "PUTVAL $HOSTNAME/${service}-${core}_core/cm7_counter-generation_diff interval=$INTERVAL N:${diff}"
      else
        echo "PUTNOTIF $HOSTNAME/${service}-${core}_core/cm7_counter-generation_diff message='N/A'"
      fi

    fi

  fi
}

# ----------------------------------------------------------------------------------------------------

while true
do
#  collectdPlugin_CMSUser

  for host in $(ls -1 ${JOLOKIA_CACHE_BASE})
  do
    HOSTNAME="${host}"

    TMP_DIR=${JOLOKIA_CACHE_BASE}/${host}

    if [ -e ${JOLOKIA_CACHE_BASE}/${host}/cm-services ]
    then
      SERVICES=${JOLOKIA_CACHE_BASE}/${host}/cm-services
    else
      continue
    fi

    if [ -f ${TMP_DIR}/PORT.cache ]
    then

      . ${TMP_DIR}/PORT.cache

      for port in ${PORTS}
      do
        service=$(grep ${port} ${SERVICES} | awk -F '=' '{ print($1) }' | sed 's/_RMI_REG//')  ## | tr '[A-Z]' '[a-z]')

        dir="${TMP_DIR}/${port}"

        for i in $(ls -1 ${dir}/*.result)
        do
          check=$(basename ${i} | sed 's|.result||g')

          case "${check}"
          in
            'Memory')                         collectdPlugin_Memory "${i}"                      ;;
            'ClassLoading')                   collectdPlugin_ClassLoading "${i}"                ;;
            'Threading')                      collectdPlugin_Threading "${i}"                   ;;
            'GarbageCollector')               collectdPlugin_GarbageCollector "${i}"            ;;
            'CMCAEBlobCache')                 collectdPlugin_CMCAEBlobCache "${i}"              ;;
            'CMCAECacheContentBeans')         collectdPlugin_CMCAECacheContentBeans "${i}"      ;;
            'CMCAEFeederProactiveEngine')     collectdPlugin_CMCAEFeederProactiveEngine "${i}"  ;;
            'CMConnectionPool')               collectdPlugin_CMConnectionPool "${i}"            ;;
            'CMQueryPool')                    collectdPlugin_CMQueryPool "${i}"                 ;;
            'CMStatisticsJobResult')          collectdPlugin_CMStatisticsJobResult "${i}"       ;;
            'CMStatisticsRepository')         collectdPlugin_CMStatisticsRepository "${i}"      ;;
            'CMContentFeeder')                collectdPlugin_CMContentFeeder "${i}"             ;;
            'CMRLSReplicator')                collectdPlugin_CMRLSReplicator "${i}" ${port}     ;;
            'CMContentDependencyInvalidator') collectdPlugin_CMFeederReplicator "${i}" ${port}  ;;
            'SolrReplicationHandler.live')    collectdPlugin_Solr "${i}" ${port}                ;;
            *)
##              echo "no plugin found: ${i}"
              continue
              ;;
          esac
        done
      done
    fi
  done

  sleep "${INTERVAL}"

done

# EOF
