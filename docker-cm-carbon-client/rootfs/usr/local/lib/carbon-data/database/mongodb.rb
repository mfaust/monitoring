
module CarbonData

  module Database

    module MongoDB


      def databaseMongoDB( value = {} )

        result = []

        if( value != nil )

          uptime         = value.dig('uptime')

          asserts        = value.dig('asserts')
          connections    = value.dig('connections')
          network        = value.dig('network')
          opcounters     = value.dig('opcounters')
          tcmalloc       = value.dig('tcmalloc')
          storageEngine  = value.dig('storageEngine')
          metrics        = value.dig('metrics')
          mem            = value.dig('mem')
          extraInfo      = value.dig('extra_info')
          wiredTiger     = value.dig('wiredTiger')
          globalLock     = value.dig('globalLock')

          result << {
            :key   => format( '%s.%s.%s', @identifier, @normalized_service_name, 'uptime' ),
            :value => uptime
          }

          if( asserts != nil )

            regular   = asserts.dig('regular')
            warning   = asserts.dig('warning')
            message   = asserts.dig('msg')
            user      = asserts.dig('user')
            rollovers = asserts.dig('rollovers')

            result << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'asserts', 'regular' ),
              :value => regular
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'asserts', 'warning' ),
              :value => warning
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'asserts', 'message' ),
              :value => message
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'asserts', 'user' ),
              :value => user
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'asserts', 'rollovers' ),
              :value => rollovers
            }

          end

          if( connections != nil )

            current        = connections.dig( 'current' )
            available      = connections.dig( 'available' )
            totalCreated   = connections.dig( 'totalCreated' )

            if( totalCreated.is_a?( Hash ) )
              totalCreated = connections.dig( 'totalCreated', '$numberLong' )
            end

            result << {
              :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'connections', 'current' ),
              :value => current
            } << {
              :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'connections', 'available' ),
              :value => available
            } << {
              :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'connections', 'created', 'total' ),
              :value => totalCreated
            }

#             result.push( format( format, @identifier, @normalized_service_name, 'connections', 'current'     , @interval, current ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'connections', 'available'   , @interval, available ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'connections', 'totalCreated', @interval, totalCreated ) )
          end

          if( network != nil )

            bytesIn   = network.dig('bytesIn')
            bytesOut  = network.dig('bytesOut')
            requests  = network.dig('numRequests')

            bytesIn   = bytesIn.dig('$numberLong')    # RX - Receive TO this server
            bytesOut  = bytesOut.dig('$numberLong')   # TX - Transmit FROM this server
            requests  = requests.dig('$numberLong')

            result << {
              :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'network', 'bytes', 'tx' ),
              :value => bytesOut
            } << {
              :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'network', 'bytes', 'rx' ),
              :value => bytesIn
            } << {
              :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'network', 'requests', 'total' ),
              :value => requests
            }

#             result.push( format( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @identifier, @normalized_service_name, 'network', 'bytes-in', @interval, bytesIn ) )
#             result.push( format( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @identifier, @normalized_service_name, 'network', 'bytes-out', @interval, bytesOut ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'network', 'total_requests' , @interval, requests ) )
          end

          if( opcounters != nil )

            insert  = opcounters.dig('insert')
            query   = opcounters.dig('query')
            update  = opcounters.dig('update')
            delete  = opcounters.dig('delete')
            getmore = opcounters.dig('getmore')
            command = opcounters.dig('command')

            result << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'opcounters', 'insert' ),
              :value => insert
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'opcounters', 'query' ),
              :value => query
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'opcounters', 'update' ),
              :value => update
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'opcounters', 'delete' ),
              :value => delete
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'opcounters', 'getmore' ),
              :value => getmore
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'opcounters', 'command' ),
              :value => command
            }

#             result.push( format( format, @identifier, @normalized_service_name, 'opcounters', 'insert'  , @interval, insert ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'opcounters', 'query'   , @interval, query ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'opcounters', 'update'  , @interval, update ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'opcounters', 'delete'  , @interval, delete ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'opcounters', 'getmore' , @interval, getmore ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'opcounters', 'command' , @interval, command ) )
          end

          if( tcmalloc != nil )

            generic = tcmalloc.dig('generic')
            malloc  = tcmalloc.dig('tcmalloc')

            heapSize         = generic.dig('heap_size')
            heapUsed         = generic.dig('current_allocated_bytes')

            percent   = ( 100 * heapUsed / heapSize )

            # pageMapFree      = tcmalloc['pageheap_free_bytes']              ? tcmalloc['pageheap_free_bytes']              : nil  # Bytes in page heap freelist
            # centralCacheFree = tcmalloc['central_cache_free_bytes' ]        ? tcmalloc['central_cache_free_bytes' ]        : nil  # Bytes in central cache freelist
            # transferCacheFee = tcmalloc['transfer_cache_free_bytes']        ? tcmalloc['transfer_cache_free_bytes']        : nil  # Bytes in transfer cache freelist
            # threadCacheSize  = tcmalloc['current_total_thread_cache_bytes'] ? tcmalloc['current_total_thread_cache_bytes'] : nil  # Bytes in thread cache freelists
            # threadCacheFree  = tcmalloc['thread_cache_free_bytes']          ? tcmalloc['thread_cache_free_bytes']          : nil  #
            # maxThreadCache   = tcmalloc['max_total_thread_cache_bytes']     ? tcmalloc['max_total_thread_cache_bytes']     : nil  #
            # maxThreadCache   = maxThreadCache['$numberLong']                ? maxThreadCache['$numberLong']                : nil  #

            result << {
              :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'memory', 'heap', 'size' ),
              :value => heapSize
            } << {
              :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'memory', 'heap', 'used' ),
              :value => heapUsed
            } << {
              :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'memory', 'heap', 'used_percent' ),
              :value => percent
            }

#             result.push( format( format, @identifier, @normalized_service_name, 'heap_memory', 'size' , @interval, heapSize ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'heap_memory', 'used' , @interval, heapUsed ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'heap_memory', 'used_percent', @interval, percent ) )
    #
            # result.push( format( format, @identifier, @normalized_service_name, 'cache', 'central_free' , @interval, centralCacheFree ) )
            # result.push( format( format, @identifier, @normalized_service_name, 'cache', 'transfer_free', @interval, transferCacheFee ) )
            # result.push( format( format, @identifier, @normalized_service_name, 'cache', 'thread_size'  , @interval, maxThreadCache ) )
            # result.push( format( format, @identifier, @normalized_service_name, 'cache', 'thread_used'  , @interval, threadCacheSize ) )
            # result.push( format( format, @identifier, @normalized_service_name, 'cache', 'thread_free'  , @interval, threadCacheFree ) )

          end

          if( storageEngine != nil )

            storageEngine  = storageEngine.dig('name')

            if( storageEngine != nil )

              storage = value.dig( storageEngine )

              if( storage != nil )

                blockManager = storage.dig('block-manager')
                connection   = storage.dig('connection')

                storageBytesRead           = blockManager.dig('bytes read')
                storageBytesWritten        = blockManager.dig('bytes written')
                storageBlocksRead          = blockManager.dig('blocks read')
                storageBlocksWritten       = blockManager.dig('blocks written')

                storageConnectionIORead    = connection.dig('total read I/Os')
                storageConnectionIOWrite   = connection.dig('total write I/Os')
                storageConnectionFilesOpen = connection.dig('files currently open')

                result << {
                  :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'storage-engine', storageEngine, 'block-manager', 'bytes', 'rx' ),
                  :value => storageBytesRead
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'storage-engine', storageEngine, 'block-manager', 'bytes', 'tx' ),
                  :value => storageBytesWritten
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'storage-engine', storageEngine, 'block-manager', 'blocks', 'rx' ),
                  :value => storageBlocksRead
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'storage-engine', storageEngine, 'block-manager', 'blocks', 'tx' ),
                  :value => storageBlocksWritten
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'storage-engine', storageEngine, 'connection', 'io', 'read', 'total' ),
                  :value => storageConnectionIORead
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'storage-engine', storageEngine, 'connection', 'io', 'write', 'total' ),
                  :value => storageConnectionIOWrite
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'storage-engine', storageEngine, 'connection', 'files', 'open' ),
                  :value => storageConnectionFilesOpen
                }

#                 result.push( format( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @identifier, @normalized_service_name, 'bytes', 'bytes-read', @interval , storageBytesRead ) )
#                 result.push( format( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @identifier, @normalized_service_name, 'bytes', 'bytes-write', @interval, storageBytesWritten ) )
#                 result.push( format( format, @identifier, @normalized_service_name, 'blocks', 'read'  , @interval, storageBlocksRead ) )
#                 result.push( format( format, @identifier, @normalized_service_name, 'blocks', 'write' , @interval, storageBlocksWritten ) )
#
#                 result.push( format( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @identifier, @normalized_service_name, 'io', 'count-read', @interval , storageConnectionIORead ) )
#                 result.push( format( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @identifier, @normalized_service_name, 'io', 'count-write', @interval, storageConnectionIOWrite ) )
#
#                 result.push( format( format, @identifier, @normalized_service_name, 'files', 'open', @interval, storageConnectionFilesOpen ) )
              end
            end
          end

          if( metrics != nil )

            commands = metrics.dig('commands')

            if( commands != nil )

              ['authenticate','buildInfo','createIndexes','delete','drop','find','findAndModify','insert','listCollections','mapReduce','renameCollection','update'].each do |m|

                cmd = commands.dig( m )

                if( cmd != nil )
    #              d = cmd['total']['$numberLong'] ? cmd['total']['$numberLong']  : nil
                  d  = cmd.dig( 'total', '$numberLong' )

                  result << {
                    :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'commands', m ),
                    :value => d
                  }

#                   result.push( format( format, @identifier, @normalized_service_name, 'commands', m , @interval, d ) )
                end
              end


              currentOp = commands.dig('currentOp')

              if (currentOp != nil)

                total  = currentOp.dig('total' , '$numberLong')
                failed = currentOp.dig('failed', '$numberLong')

                result << {
                  :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'commands', 'currentOp', 'total' ),
                  :value => total
                } << {
                  :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'commands', 'currentOp', 'failed' ),
                  :value => failed
                }

#                 result.push( format( format, @identifier, @normalized_service_name, 'currentOp', 'total',  @interval, total ) )
#                 result.push( format( format, @identifier, @normalized_service_name, 'currentOp', 'failed', @interval, failed ) )
              end

            end

            cursor = metrics.dig('cursor')

            if( cursor != nil )

              cursorOpen     = cursor.dig('open')
              cursorTimedOut = cursor.dig('timedOut')

              if( cursorOpen != nil && cursorTimedOut != nil )

                openNoTimeout = cursorOpen.dig( 'noTimeout', '$numberLong' )
                openTotal     = cursorOpen.dig( 'total'    , '$numberLong' )
                timedOut      = cursorTimedOut.dig( '$numberLong' )

                result << {
                  :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'cursor', 'open', 'total' ),
                  :value => openTotal
                } << {
                  :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'cursor', 'open', 'no-timeout' ),
                  :value => openNoTimeout
                } << {
                  :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'cursor', 'timed-out' ),
                  :value => timedOut
                }

#                 result.push( format( format, @identifier, @normalized_service_name, 'cursor', 'open-total',      @interval, openTotal ) )
#                 result.push( format( format, @identifier, @normalized_service_name, 'cursor', 'open-no-timeout', @interval, openNoTimeout ) )
#                 result.push( format( format, @identifier, @normalized_service_name, 'cursor', 'timed-out',       @interval, timedOut ) )
              end

            end

          end

          if( mem != nil )

            virtual        = mem.dig('virtual')
            resident       = mem.dig('resident')

            result << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'memory', 'virtual' ),
              :value => virtual
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'memory', 'resident' ),
              :value => resident
            }

#             result.push( format( format, @identifier, @normalized_service_name, 'mem', 'virtual'    , @interval, virtual ) )
#             result.push( format( format, @identifier, @normalized_service_name, 'mem', 'resident'   , @interval, resident ) )
          end

          if( extraInfo != nil )

            pageFaults        = extraInfo.dig('page_faults')

            result << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'extraInfo', 'pageFaults' ),
              :value => pageFaults
            }

#             result.push( format( format, @identifier, @normalized_service_name, 'extraInfo', 'pageFaults' , @interval, pageFaults ) )
          end

          if( wiredTiger != nil )

            wiredTigerCache        = wiredTiger.dig('cache')
            concurrentTransactions = wiredTiger.dig('concurrentTransactions')

            if( wiredTigerCache != nil )

              bytes         = wiredTigerCache.dig('bytes currently in the cache')
              maximum       = wiredTigerCache.dig('maximum bytes configured')
              tracked       = wiredTigerCache.dig('tracked dirty bytes in the cache')
              unmodified    = wiredTigerCache.dig('unmodified pages evicted')
              modified      = wiredTigerCache.dig('modified pages evicted')

              result << {
                :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'cache', 'in-cache', 'bytes' ),
                :value => bytes
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'cache', 'in-cache', 'tracked-dirty' ),
                :value => tracked
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'cache', 'configured', 'max-bytes' ),
                :value => maximum
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'cache', 'evicted-pages', 'modified' ),
                :value => modified
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'cache', 'evicted-pages', 'unmodified' ),
                :value => unmodified
              }

#               result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerCache', 'bytes'      , @interval, bytes ) )
#               result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerCache', 'maximum'    , @interval, maximum ) )
#               result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerCache', 'tracked'    , @interval, tracked ) )
#               result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerCache', 'unmodified' , @interval, unmodified ) )
#               result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerCache', 'modified'   , @interval, modified ) )
            end

            if( concurrentTransactions != nil )

              read        = concurrentTransactions.dig('read')
              write       = concurrentTransactions.dig('write')

              if( read != nil && write != nil )

                readOut          = read.dig('out')
                readAvailable    = read.dig('available')

                writeOut         = write.dig('out')
                writeAvailable   = write.dig('available')

                result << {
                  :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'concurrentTransactions', 'read', 'out' ),
                  :value => readOut
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'concurrentTransactions', 'read', 'available' ),
                  :value => readAvailable
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'concurrentTransactions', 'write', 'out' ),
                  :value => writeOut
                } << {
                  :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'wiredTiger', 'concurrentTransactions', 'write', 'available' ),
                  :value => writeAvailable
                }

#                 result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerConcTrans', 'readOut'          , @interval, readOut ) )
#                 result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerConcTrans', 'readAvailable'    , @interval, readAvailable ) )
#                 result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerConcTrans', 'writeOut'         , @interval, writeOut ) )
#                 result.push( format( format, @identifier, @normalized_service_name, 'wiredTigerConcTrans', 'writeAvailable'   , @interval, writeAvailable ) )
              end

            end
          end

          if( globalLock != nil )

            currentQueue  = globalLock.dig('currentQueue')
            activeClients = globalLock.dig('activeClients')

            if( currentQueue != nil )

              readers       = currentQueue.dig('readers')
              writers       = currentQueue.dig('writers')
              total         = currentQueue.dig('total')

              result << {
                :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'globalLock', 'currentQueue', 'readers' ),
                :value => readers
              } << {
                :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'globalLock', 'currentQueue', 'writers' ),
                :value => writers
              } << {
                :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'globalLock', 'currentQueue', 'total' ),
                :value => total
              }

#               result.push( format( format, @identifier, @normalized_service_name, 'globalLockCurrentQueue', 'readers'    , @interval, readers ) )
#               result.push( format( format, @identifier, @normalized_service_name, 'globalLockCurrentQueue', 'writers'    , @interval, writers ) )
#               result.push( format( format, @identifier, @normalized_service_name, 'globalLockCurrentQueue', 'total'      , @interval, total ) )
            end

            if( activeClients != nil )

              readers     = activeClients.dig('readers')
              writers     = activeClients.dig('writers')
              total       = activeClients.dig('total')

              result << {
                :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'globalLock', 'activeClients', 'readers' ),
                :value => readers
              } << {
                :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'globalLock', 'activeClients', 'writers' ),
                :value => writers
              } << {
                :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'globalLock', 'activeClients', 'total' ),
                :value => total
              }

#               result.push( format( format, @identifier, @normalized_service_name, 'globalLockActiveClients', 'readers'    , @interval, readers ) )
#               result.push( format( format, @identifier, @normalized_service_name, 'globalLockActiveClients', 'writers'    , @interval, writers ) )
#               result.push( format( format, @identifier, @normalized_service_name, 'globalLockActiveClients', 'total'      , @interval, total ) )
            end
          end

          return result

        end
      end

    end

  end

end
