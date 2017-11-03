
module MessageQueue

  class Producer

    include Logging

    def initialize( params = {} )

      beanstalkHost       = params.dig(:beanstalkHost) || 'beanstalkd'
      beanstalkPort       = params.dig(:beanstalkPort) || 11300

      begin
        @b = Beaneater.new( sprintf( '%s:%s', beanstalkHost, beanstalkPort ) )
      rescue => e
        logger.error( e )
        @b = nil
#        raise sprintf( 'ERROR: %s' , e )
      end

#       logger.info( '-----------------------------------------------------------------' )
#       logger.info( ' MessageQueue::Producer' )
#       logger.info( '-----------------------------------------------------------------' )

    end

    # add an Job to an names Message Queue
    #
    # @param [String, #read] tube the Queue Name
    # @param [Hash, #read] job the Jobdata will send to Message Queue
    # @param [Integer, #read] prio is an integer < 2**32. Jobs with smaller priority values will be
    #        scheduled before jobs with larger priorities. The most urgent priority is 0;
    #        the least urgent priority is 4,294,967,295.
    # @param [Integer, #read] ttr time to run -- is an integer number of seconds to allow a worker
    #        to run this job. This time is counted from the moment a worker reserves
    #        this job. If the worker does not delete, release, or bury the job within
    # <ttr> seconds, the job will time out and the server will release the job.
    #        The minimum ttr is 1. If the client sends 0, the server will silently
    #        increase the ttr to 1.
    # @param [Integer, #read] delay is an integer number of seconds to wait before putting the job in
    #        the ready queue. The job will be in the "delayed" state during this time.
    # @example send a Job to Beanaeter
    #    addJob()
    # @return [Hash,#read]
    #
    def addJob( tube, job = {}, prio = 65536, ttr = 10, delay = 2 )

      if( @b )

        # check if job already in the queue
        #
        if( self.jobExists?( tube.to_s, job ) == true )
          return
        end

        response = @b.tubes[ tube.to_s ].put( job , :prio => prio, :ttr => ttr, :delay => delay )

        logger.debug( response )
      end

    end



    def jobExists?( tube, job )

      if( job.is_a?( String ) )
        job = JSON.parse(job)
      end

      j_checksum = self.checksum(job)

      if( @b )

        t = @b.tubes[ tube.to_s ]

        while t.peek(:ready)

          j = t.reserve

          b = JSON.parse( j.body )

          if( b.is_a?( String ) )
            b = JSON.parse( b )
          end

          b_checksum = self.checksum(b)

          if( j_checksum == b_checksum )
            logger.warn( "  job '#{job}' already in queue .." )
            return true
          else
            return false
          end

        end
      end
    end


    def checksum( p )

      p.reject! { |k| k == 'timestamp' }
      p.reject! { |k| k == 'payload' }

      p = Hash[p.sort]
      return Digest::MD5.hexdigest(p.to_s)
    end

  end
end

