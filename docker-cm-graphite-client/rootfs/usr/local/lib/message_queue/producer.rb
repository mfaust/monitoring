
module MessageQueue

  class Producer

    include Logging

    def initialize( params = {} )

      beanstalk_host       = params.dig(:beanstalk_host) || 'beanstalkd'
      beanstalk_port       = params.dig(:beanstalk_port) || 11300

      begin
        @b = Beaneater.new( format( '%s:%s', beanstalk_host, beanstalk_port ) )
      rescue => e
        logger.error( e )
        @b = nil
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
    #    add_job()
    # @return [Hash,#read]
    #
    def add_job( tube, job, prio = 65536, ttr = 10, delay = 2 )

      if( @b )
        # check if job already in the queue
        #
        return { status: 200, message: 'job exists' } if( job_exists?( tube.to_s, job ) == true )

        response = @b.tubes[tube.to_s].put( job, { prio: prio, ttr: ttr, delay: delay } )

        logger.debug( response )
      end

    end



    def job_exists?( tube, job )

      job = JSON.parse(job) if( job.is_a?( String ) )

      j_checksum = checksum(job)

      if( @b )

        t = @b.tubes[ tube.to_s ]

        while t.peek(:ready)

          j = t.reserve

          b = JSON.parse( j.body )
          b = JSON.parse( b ) if( b.is_a?( String ) )

          b_checksum = checksum(b)

          logger.warn( "  job '#{job}' already in queue .." ) if( j_checksum == b_checksum )

          return true if( j_checksum == b_checksum )
          return false
        end
      end
    end


    def checksum( p )

      p.reject! { |k| k == 'timestamp' }
      p.reject! { |k| k == 'payload' }

      Digest::MD5.hexdigest(Hash[p.sort].to_s)
    end

  end
end

