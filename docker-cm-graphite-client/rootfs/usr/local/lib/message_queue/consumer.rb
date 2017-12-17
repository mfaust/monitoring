
module MessageQueue

  class Consumer

    include Logging

    def initialize( params = {} )

      beanstalk_host         = params.dig(:beanstalk_host)         || 'beanstalkd'
      beanstalk_port         = params.dig(:beanstalk_port)         ||  11300
      beanstalk_queue        = params.dig(:beanstalk_queue)
      release_buried_interval = params.dig(:release_buried_interval) || 40

      begin
        @b = Beaneater.new( format( '%s:%s', beanstalk_host, beanstalk_port ) )

        if( beanstalk_queue != nil )

          scheduler = Rufus::Scheduler.new

          scheduler.every( release_buried_interval ) do
            release_buried_jobs( beanstalk_queue )
          end
        else
          logger.info( 'no Queue defined. Skip release_buried_jobs() Part' )
        end

      rescue => e
        logger.error( e )
        raise format( 'ERROR: %s' , e )
      end

#       logger.info( '-----------------------------------------------------------------' )
#       logger.info( ' MessageQueue::Consumer' )
#       logger.info( '-----------------------------------------------------------------' )

    end


    def tube_statistics( tube )

      queue       = nil
      jobs_total   = 0
      jobs_ready   = 0
      jobs_delayed = 0
      jobs_buried  = 0
      tube_stats   = nil

      if( @b )

        begin
          tube_stats = @b.tubes[tube].stats

          if( tube_stats )

            queue        = tube_stats[:name]
            jobs_total   = tube_stats[:total_jobs]
            jobs_ready   = tube_stats[:current_jobs_ready]
            jobs_delayed = tube_stats[:current_jobs_delayed]
            jobs_buried  = tube_stats[:current_jobs_buried]
          end
        rescue Beaneater::NotFoundError

        end
      end

      return {
        queue: queue,
        total: jobs_total.to_i,
        ready: jobs_ready.to_i,
        delayed: jobs_delayed.to_i,
        buried: jobs_buried.to_i,
        raw: tube_stats
      }

    end


    def clean_queue( tube )

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

            delete_job( tube, j.id )

#            logger.debug( "remove job id: #{j.id}" )
#            logger.debug( r )
#            j.delete
          end

        end

      end

    end



    def get_job_from_tube( tube, delete = false )

      result = {}

      if( @b )

        stats = tube_statistics( tube )

        return result if( stats.dig( :ready ) == 0 )

        tube = @b.tubes.watch!( tube.to_s )

        begin
          job = @b.tubes.reserve(1)

          begin
            # processing job

            result = {
              id: job.id,
              tube: job.stats.tube,
              state: job.stats.state,
              ttr: job.stats.ttr,
              prio: job.stats.pri,
              age: job.stats.age,
              delay: job.stats.delay,
              body: JSON.parse( job.body )
            }

            job.delete if( delete == true )

          rescue Exception => e
            job.bury
          end

        rescue Beaneater::TimedOutError
          # nothing to do
        end
      end

      result
    end


    def release_buried_jobs( tube )

      if( @b )

        tube = @b.tubes.find( tube.to_s )

        buried = tube.peek( :buried )

        if( buried )
          logger.info( format( 'found job: %d, kick them back into the \'ready\' queue', buried.id ) )
          tube.kick(1)
        end
      end
    end


    def delete_job( tube, id )

      logger.debug( format( "delete_job( #{tube}, #{id} )" ) )

      if( @b )
        job = @b.jobs.find( id )

        job.delete if( job != nil )
      end
    end


    def bury_job( tube, id )

      logger.debug( format( "bury_job( #{tube}, #{id} )" ) )

      if( @b )
        job = @b.jobs.find( id )

        job.bury if( job != nil )
      end
    end

  end

end
