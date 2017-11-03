
module MessageQueue

  class Consumer

    include Logging

    def initialize( params = {} )

      beanstalkHost         = params.dig(:beanstalkHost)         || 'beanstalkd'
      beanstalkPort         = params.dig(:beanstalkPort)         ||  11300
      beanstalkQueue        = params.dig(:beanstalkQueue)
      releaseBuriedInterval = params.dig(:releaseBuriedInterval) || 40

      begin
        @b = Beaneater.new( sprintf( '%s:%s', beanstalkHost, beanstalkPort ) )

        if( beanstalkQueue != nil )

          scheduler = Rufus::Scheduler.new

          scheduler.every( releaseBuriedInterval ) do
            releaseBuriedJobs( beanstalkQueue )
          end
        else
          logger.info( 'no Queue defined. Skip releaseBuriedJobs() Part' )
        end

      rescue => e
        logger.error( e )
        raise sprintf( 'ERROR: %s' , e )
      end

#       logger.info( '-----------------------------------------------------------------' )
#       logger.info( ' MessageQueue::Consumer' )
#       logger.info( '-----------------------------------------------------------------' )

    end


    def tubeStatistics( tube )

      queue       = nil
      jobsTotal   = 0
      jobsReady   = 0
      jobsDelayed = 0
      jobsBuried  = 0
      tubeStats   = nil

      if( @b )

        begin
          tubeStats = @b.tubes[tube].stats

          if( tubeStats )

            queue       = tubeStats[ :name ]
            jobsTotal   = tubeStats[ :total_jobs ]
            jobsReady   = tubeStats[ :current_jobs_ready ]
            jobsDelayed = tubeStats[ :current_jobs_delayed ]
            jobsBuried  = tubeStats[ :current_jobs_buried ]
          end
        rescue Beaneater::NotFoundError

        end
      end

      return {
        :queue   => queue,
        :total   => jobsTotal.to_i,
        :ready   => jobsReady.to_i,
        :delayed => jobsDelayed.to_i,
        :buried  => jobsBuried.to_i,
        :raw     => tubeStats
      }

    end


    def cleanQueue( tube )

      b = Array.new()

      sleep(0.3)
      timeout = nil
      jobs = []

      begin
        100.times do |i|
          jobs << @b.tubes[tube].reserve(timeout)
          timeout = 0
        end
      rescue Beaneater::TimedOutError
        # nothing to do
      end

      jobs.map do |j|

#         logger.debug( JSON.pretty_generate( {
#                   'id'    => j.id,
#                   'tube'  => j.stats.tube,
#                   'state' => j.stats.state,
#                   'ttr'   => j.stats.ttr,
#                   'prio'  => j.stats.pri,
#                   'age'   => j.stats.age,
#                   'delay' => j.stats.delay,
#                   'body'  => JSON.parse( j.body )
#                 } )

        body = JSON.parse( j.body )

        body['id'] = j.id
        body.reject! { |k| k == 'timestamp' }
        body.reject! { |k| k == 'payload' }
        body = Hash[body.sort]

        logger.debug( body )
        b << body
      end

      # sort reverse
      #
      b = b.sort_by { |x| x['id'].to_i }.reverse

      logger.debug( b.count )
      logger.debug( b )

      # unique entries
      #
      c = b.uniq { |t| [ t['cmd'], t['node'] ] }

      identicalEntries      = b & c
      removedEntries        = b - c

      jobs.map do |j|

        removedEntries.each do |r|

          if j.id == r.dig('id' )

            self.deleteJob( tube, j.id )

#            logger.debug( "remove job id: #{j.id}" )
#            logger.debug( r )
#            j.delete
          end

        end

      end

    end



    def getJobFromTube( tube, delete = false )

      result = {}

      if( @b )

        stats = self.tubeStatistics( tube )

        if( stats.dig( :ready ) == 0 )
          return result
        end

        tube = @b.tubes.watch!( tube.to_s )

        begin
          job = @b.tubes.reserve(1)

          begin
            # processing job

            result = {
              :id    => job.id,
              :tube  => job.stats.tube,
              :state => job.stats.state,
              :ttr   => job.stats.ttr,
              :prio  => job.stats.pri,
              :age   => job.stats.age,
              :delay => job.stats.delay,
              :body  => JSON.parse( job.body )
            }

            if( delete == true )
              job.delete
            end

          rescue Exception => e
            job.bury
          end

        rescue Beaneater::TimedOutError
          # nothing to do
        end
      end

      return result
    end


    def releaseBuriedJobs( tube )

      if( @b )

        tube = @b.tubes.find( tube.to_s )

        buried = tube.peek( :buried )

        if( buried )
          logger.info( sprintf( 'found job: %d, kick them back into the \'ready\' queue', buried.id ) )

          tube.kick(1)
        end
      end
    end


    def deleteJob( tube, id )

      logger.debug( sprintf( "deleteJob( #{tube}, #{id} )" ) )

      if( @b )

        job = @b.jobs.find( id )

        if( job != nil )
          response = job.delete
        end
      end
    end


    def buryJob( tube, id )

      logger.debug( sprintf( "buryJob( #{tube}, #{id} )" ) )

      if( @b )

        job = @b.jobs.find( id )

        if( job != nil )
          response = job.bury
        end
      end
    end

  end

end
