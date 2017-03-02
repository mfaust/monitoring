
module CarbonData

  module Database

    module MongoDB


      def databaseMongoDB( value = {} )

        format = 'PUTVAL %s/%s-%s/count-%s interval=%s N:%s'
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
            :key   => sprintf( '%s.%s.%s', @Host, @Service, 'uptime' ),
            :value => uptime
          }

#           result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'uptime', 'uptime'   , @interval, uptime ) )

          if( asserts != nil )

            regular   = asserts.dig('regular')
            warning   = asserts.dig('warning')
            message   = asserts.dig('msg')
            user      = asserts.dig('user')
            rollovers = asserts.dig('rollovers')

            result << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'asserts', 'regular' ),
              :value => regular
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'asserts', 'warning' ),
              :value => warning
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'asserts', 'message' ),
              :value => message
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'asserts', 'user' ),
              :value => user
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'asserts', 'rollovers' ),
              :value => rollovers
            }

            result.push( sprintf( format, @Host, @Service, 'asserts', 'regular'   , @interval, regular ) )
            result.push( sprintf( format, @Host, @Service, 'asserts', 'warning'   , @interval, warning ) )
            result.push( sprintf( format, @Host, @Service, 'asserts', 'message'   , @interval, message ) )
            result.push( sprintf( format, @Host, @Service, 'asserts', 'user'      , @interval, user ) )
            result.push( sprintf( format, @Host, @Service, 'asserts', 'rollovers' , @interval, rollovers ) )
          end

          if( connections != nil )

            logger.debug( JSON.pretty_generate( connections ) )

            current        = connections.dig( 'current' )
            available      = connections.dig( 'available' )
            totalCreated   = connections.dig( 'totalCreated' )

#             if( totalCreated != nil )
#               totalCreated = connections.dig( '$numberLong' )
#             else
#               totalCreated = nil
#             end

            result << {
              :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, 'connections', 'current' ),
              :value => current
            } << {
              :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, 'connections', 'available' ),
              :value => available
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'connections', 'created', 'total' ),
              :value => totalCreated
            }

            result.push( sprintf( format, @Host, @Service, 'connections', 'current'     , @interval, current ) )
            result.push( sprintf( format, @Host, @Service, 'connections', 'available'   , @interval, available ) )
            result.push( sprintf( format, @Host, @Service, 'connections', 'totalCreated', @interval, totalCreated ) )
          end

          if( network != nil )

            bytesIn   = network.dig('bytesIn')
            bytesOut  = network.dig('bytesOut')
            requests  = network.dig('numRequests')

            bytesIn   = bytesIn.dig('$numberLong')    # RX - Receive TO this server
            bytesOut  = bytesOut.dig('$numberLong')   # TX - Transmit FROM this server
            requests  = requests.dig('$numberLong')

            result << {
              :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'network', 'bytes', 'tx' ),
              :value => bytesIn
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'network', 'bytes', 'rx' ),
              :value => bytesOut
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'network', 'requests', 'total' ),
              :value => requests
            }

            result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'network', 'bytes-in', @interval, bytesIn ) )
            result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'network', 'bytes-out', @interval, bytesOut ) )
            result.push( sprintf( format, @Host, @Service, 'network', 'total_requests' , @interval, requests ) )
          end

          if( opcounters != nil )

            insert  = opcounters.dig('insert')
            query   = opcounters.dig('query')
            update  = opcounters.dig('update')
            delete  = opcounters.dig('delete')
            getmore = opcounters.dig('getmore')
            command = opcounters.dig('command')

            result << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'opcounters', 'insert' ),
              :value => insert
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'opcounters', 'query' ),
              :value => query
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'opcounters', 'update' ),
              :value => update
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'opcounters', 'delete' ),
              :value => delete
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'opcounters', 'getmore' ),
              :value => getmore
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'opcounters', 'command' ),
              :value => command
            }

            result.push( sprintf( format, @Host, @Service, 'opcounters', 'insert'  , @interval, insert ) )
            result.push( sprintf( format, @Host, @Service, 'opcounters', 'query'   , @interval, query ) )
            result.push( sprintf( format, @Host, @Service, 'opcounters', 'update'  , @interval, update ) )
            result.push( sprintf( format, @Host, @Service, 'opcounters', 'delete'  , @interval, delete ) )
            result.push( sprintf( format, @Host, @Service, 'opcounters', 'getmore' , @interval, getmore ) )
            result.push( sprintf( format, @Host, @Service, 'opcounters', 'command' , @interval, command ) )
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
              :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'memory', 'heap', 'size' ),
              :value => heapSize
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'memory', 'heap', 'used' ),
              :value => heapUsed
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'memory', 'heap', 'used_percent' ),
              :value => percent
            }

            result.push( sprintf( format, @Host, @Service, 'heap_memory', 'size' , @interval, heapSize ) )
            result.push( sprintf( format, @Host, @Service, 'heap_memory', 'used' , @interval, heapUsed ) )
            result.push( sprintf( format, @Host, @Service, 'heap_memory', 'used_percent', @interval, percent ) )
    #
            # result.push( sprintf( format, @Host, @Service, 'cache', 'central_free' , @interval, centralCacheFree ) )
            # result.push( sprintf( format, @Host, @Service, 'cache', 'transfer_free', @interval, transferCacheFee ) )
            # result.push( sprintf( format, @Host, @Service, 'cache', 'thread_size'  , @interval, maxThreadCache ) )
            # result.push( sprintf( format, @Host, @Service, 'cache', 'thread_used'  , @interval, threadCacheSize ) )
            # result.push( sprintf( format, @Host, @Service, 'cache', 'thread_free'  , @interval, threadCacheFree ) )

          end

          if( storageEngine != nil )

            storageEngine  = storageEngine.dig('name')

            if( storageEngine != nil )

              storage = value.dig( storageEngine )

              if( storage != nil )

                blockManager = storage.dig('block-manager')
                connection   = storage.dig('connection')

                logger.debug( JSON.pretty_generate( connection ) )

                storageBytesRead           = blockManager.dig('bytes read')
                storageBytesWritten        = blockManager.dig('bytes written')
                storageBlocksRead          = blockManager.dig('blocks read')
                storageBlocksWritten       = blockManager.dig('blocks written')

                storageConnectionIORead    = connection.dig('total read I/Os')
                storageConnectionIOWrite   = connection.dig('total write I/O')
                storageConnectionFilesOpen = connection.dig('files currently open')

                result << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, 'storage-engine', storageEngine, 'block-manager', 'bytes', 'rx' ),
                  :value => storageBytesRead
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, 'storage-engine', storageEngine, 'block-manager', 'bytes', 'tx' ),
                  :value => storageBytesWritten
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, 'storage-engine', storageEngine, 'block-manager', 'blocks', 'rx' ),
                  :value => storageBlocksRead
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, 'storage-engine', storageEngine, 'block-manager', 'blocks', 'tx' ),
                  :value => storageBlocksWritten
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s.%s', @Host, @Service, 'storage-engine', storageEngine, 'connection', 'io', 'read', 'total' ),
                  :value => storageConnectionIORead
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s.%s', @Host, @Service, 'storage-engine', storageEngine, 'connection', 'io', 'write', 'total' ),
                  :value => storageConnectionIOWrite
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, 'storage-engine', storageEngine, 'connection', 'files', 'open' ),
                  :value => storageConnectionFilesOpen
                }

                result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'bytes', 'bytes-read', @interval , storageBytesRead ) )
                result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'bytes', 'bytes-write', @interval, storageBytesWritten ) )
                result.push( sprintf( format, @Host, @Service, 'blocks', 'read'  , @interval, storageBlocksRead ) )
                result.push( sprintf( format, @Host, @Service, 'blocks', 'write' , @interval, storageBlocksWritten ) )

                result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'io', 'count-read', @interval , storageConnectionIORead ) )
                result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'io', 'count-write', @interval, storageConnectionIOWrite ) )

                result.push( sprintf( format, @Host, @Service, 'files', 'open', @interval, storageConnectionFilesOpen ) )
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
                    :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, 'commands', m ),
                    :value => d
                  }

                  result.push( sprintf( format, @Host, @Service, 'commands', m , @interval, d ) )
                end
              end


              currentOp = commands.dig('currentOp')

              if (currentOp != nil)

                total  = currentOp.dig('total' , '$numberLong')
                failed = currentOp.dig('failed', '$numberLong')

                result << {
                  :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'commands', 'currentOp', 'total' ),
                  :value => total
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'commands', 'currentOp', 'failed' ),
                  :value => failed
                }


                result.push( sprintf( format, @Host, @Service, 'currentOp', 'total',  @interval, total ) )
                result.push( sprintf( format, @Host, @Service, 'currentOp', 'failed', @interval, failed ) )
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
                  :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'cursor', 'open', 'total' ),
                  :value => openTotal
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'cursor', 'open', 'no-timeout' ),
                  :value => openNoTimeout
                } << {
                  :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, 'cursor', 'timed-out' ),
                  :value => timedOut
                }

                result.push( sprintf( format, @Host, @Service, 'cursor', 'open-total',      @interval, openTotal ) )
                result.push( sprintf( format, @Host, @Service, 'cursor', 'open-no-timeout', @interval, openNoTimeout ) )
                result.push( sprintf( format, @Host, @Service, 'cursor', 'timed-out',       @interval, timedOut ) )
              end

            end

          end

          if( mem != nil )

            virtual        = mem.dig('virtual')
            resident       = mem.dig('resident')

            result << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'memory', 'virtual' ),
              :value => virtual
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'memory', 'resident' ),
              :value => resident
            }

            result.push( sprintf( format, @Host, @Service, 'mem', 'virtual'    , @interval, virtual ) )
            result.push( sprintf( format, @Host, @Service, 'mem', 'resident'   , @interval, resident ) )
          end

          if( extraInfo != nil )

            pageFaults        = extraInfo.dig('page_faults')

            result << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'extraInfo', 'pageFaults' ),
              :value => pageFaults
            }

            result.push( sprintf( format, @Host, @Service, 'extraInfo', 'pageFaults' , @interval, pageFaults ) )
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
                :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'cache', 'in-cache', 'bytes' ),
                :value => bytes
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'cache', 'in-cache', 'tracked-dirty' ),
                :value => tracked
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'cache', 'configured', 'max-bytes' ),
                :value => maximum
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'cache', 'evicted-pages', 'modified' ),
                :value => modified
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'cache', 'evicted-pages', 'unmodified' ),
                :value => unmodified
              }

              result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'bytes'      , @interval, bytes ) )
              result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'maximum'    , @interval, maximum ) )
              result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'tracked'    , @interval, tracked ) )
              result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'unmodified' , @interval, unmodified ) )
              result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'modified'   , @interval, modified ) )
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
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'concurrentTransactions', 'read', 'out' ),
                  :value => readOut
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'concurrentTransactions', 'read', 'available' ),
                  :value => readAvailable
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'concurrentTransactions', 'write', 'out' ),
                  :value => writeOut
                } << {
                  :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'wiredTiger', 'concurrentTransactions', 'write', 'available' ),
                  :value => writeAvailable
                }

                result.push( sprintf( format, @Host, @Service, 'wiredTigerConcTrans', 'readOut'          , @interval, readOut ) )
                result.push( sprintf( format, @Host, @Service, 'wiredTigerConcTrans', 'readAvailable'    , @interval, readAvailable ) )
                result.push( sprintf( format, @Host, @Service, 'wiredTigerConcTrans', 'writeOut'         , @interval, writeOut ) )
                result.push( sprintf( format, @Host, @Service, 'wiredTigerConcTrans', 'writeAvailable'   , @interval, writeAvailable ) )
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
                :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'globalLock', 'currentQueue', 'readers' ),
                :value => readers
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'globalLock', 'currentQueue', 'writers' ),
                :value => writers
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'globalLock', 'currentQueue', 'total' ),
                :value => total
              }

              result.push( sprintf( format, @Host, @Service, 'globalLockCurrentQueue', 'readers'    , @interval, readers ) )
              result.push( sprintf( format, @Host, @Service, 'globalLockCurrentQueue', 'writers'    , @interval, writers ) )
              result.push( sprintf( format, @Host, @Service, 'globalLockCurrentQueue', 'total'      , @interval, total ) )
            end

            if( activeClients != nil )

              readers     = activeClients.dig('readers')
              writers     = activeClients.dig('writers')
              total       = activeClients.dig('total')

              result << {
                :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'globalLock', 'activeClients', 'readers' ),
                :value => readers
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'globalLock', 'activeClients', 'writers' ),
                :value => writers
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, 'globalLock', 'activeClients', 'total' ),
                :value => total
              }

              result.push( sprintf( format, @Host, @Service, 'globalLockActiveClients', 'readers'    , @interval, readers ) )
              result.push( sprintf( format, @Host, @Service, 'globalLockActiveClients', 'writers'    , @interval, writers ) )
              result.push( sprintf( format, @Host, @Service, 'globalLockActiveClients', 'total'      , @interval, total ) )
            end
          end

          return result

        end
      end

    end

  end

end
