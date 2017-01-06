#!/usr/bin/ruby
#
# 05.01.2017 - Bodo Schulz
# v1.0.1
#
# simplified API for Beanaeter (Client Class for beanstalk)

# -----------------------------------------------------------------------------

require 'beaneater'
require 'json'
require 'logger'
require_relative 'logging'

# -----------------------------------------------------------------------------

module MessageQueue

  class Producer

    include Logging

    def initialize( params = {} )

      beanstalkHost       = params[:beanstalkHost] ? params[:beanstalkHost] : 'beanstalkd'
      beanstalkPort       = params[:beanstalkPort] ? params[:beanstalkPort] : 11300

      begin
        @b = Beaneater.new( sprintf( '%s:%s', beanstalkHost, beanstalkPort ) )
      rescue => e
        logger.error( e )
      end

    end

    def addJob( tube, job = {}, delay = 2 )

      if( @b )

#         logger.debug( "add job to tube #{tube}" )
#         logger.debug( job )

#        tube = @b.use( tube.to_s )
        response = @b.tubes[ tube.to_s ].put( job , :ttr => 10, :delay => delay )

#         logger.debug( response )
      end

    end

  end



  class Consumer

    include Logging

    def initialize( params = {} )

      beanstalkHost       = params[:beanstalkHost] ? params[:beanstalkHost] : 'beanstalkd'
      beanstalkPort       = params[:beanstalkPort] ? params[:beanstalkPort] : 11300

      @b = Beaneater.new( sprintf( '%s:%s', beanstalkHost, beanstalkPort ) )

    end


    def tubeStatistics( tube )

      jobsTotal   = 0
      jobsReady   = 0
      jobsDelayed = 0
      jobsBuried  = 0
      tubeStats   = nil

      if( @b )

        begin
          tubeStats = @b.tubes[tube].stats

          if( tubeStats )

            jobsTotal   = tubeStats[ :total_jobs ]
            jobsReady   = tubeStats[ :current_jobs_ready ]
            jobsDelayed = tubeStats[ :current_jobs_delayed ]
            jobsBuried  = tubeStats[ :current_jobs_buried ]
          end
        rescue Beaneater::NotFoundError

        end
      end

      return {
        :total   => jobsTotal.to_i,
        :ready   => jobsReady.to_i,
        :delayed => jobsDelayed.to_i,
        :buried  => jobsBuried.to_i,
        :raw     => tubeStats
      }

    end



    def getJobFromTube( tube )

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

            job.delete

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

        while( job = tube.peek( :buried ) )

          logger.debug( job.stats )

          response = job.release()

          logger.debug( response )
        end

      end

    end


  end

end

# -----------------------------------------------------------------------------
# TESTS

# settings = {
#   :beanstalkHost => 'localhost'
# }
#
# p = MessageQueue::Producer.new( settings )
#
#
# 100.times do |i|
#
#   job = {
#     cmd:   'add',
#     payload: sprintf( "foo-bar-%s.com", i )
#   }.to_json
#
#   p.addJob( 'test-tube', job )
# end
#
# c = MessageQueue::Consumer.new( settings )
#
# puts JSON.pretty_generate( c.tubeStatistics( 'test-tube' ) )
#
# loop do
#   j = c.getJobFromTube( 'test-tube' )
#
#   if( j.count == 0 )
#     break
#   else
#     puts JSON.pretty_generate( j )
#   end
# end

# -----------------------------------------------------------------------------
