#!/usr/bin/ruby

require 'json'


# Generated from /proc/meminfo.
#
#    MemUsed         -  Total size of used memory in kilobytes.
#    MemFree         -  Total size of free memory in kilobytes.
#    MemUsedPer      -  Total size of used memory in percent.
#    MemTotal        -  Total size of memory in kilobytes.
#    Buffers         -  Total size of buffers used from memory in kilobytes.
#    Cached          -  Total size of cached memory in kilobytes.
#    SwapUsed        -  Total size of swap space is used is kilobytes.
#    SwapFree        -  Total size of swap space is free in kilobytes.
#    SwapUsedPer     -  Total size of swap space is used in percent.
#    SwapTotal       -  Total size of swap space in kilobytes.

def collectMemInfo()

  result = Hash.new()

  file = '/proc/meminfo'

  if( File.exists?( file ) )

    puts 'read meminfo'

    File.open( file, 'r' ) do |l|

      l.each do |line|
        key, value = line.chomp.split
        result[key.tr(': _','')] = value
      end
    end

  end

  return JSON.pretty_generate( Hash[result.sort] )
end

# Generated with /proc/loadavg.
#
#    AVG_1           -  The average processor workload of the last minute.
#    AVG_5           -  The average processor workload of the last five minutes.
#    AVG_15          -  The average processor workload of the last fifteen minutes.
#    RunQueue        -  The number of processes waiting for runtime.
#    Count           -  The total amount of processes on the system.

def collectLoadAvg()

  result = Hash.new()

  file = '/proc/loadavg'

  if( File.exists?( file ) )

    puts 'read loadavg'

    File.open( file, 'r' ) do |l|

      l.each do |line|

        result = {
          'load1'  => line.split[0].to_f.to_s,
          'load5'  => line.split[1].to_f.to_s,
          'load15' => line.split[2].to_f.to_s
        }

      end
    end

  end

  return JSON.pretty_generate( Hash[result.sort] )

end

#    This function collects CPU Information and reports iteration
#    via metrics.  The data is harvested from the /proc/stat file.
#    The first line of information in that file is formatted as
#    follows:
#      cpu <user> <nice> <system> <idle> <iowait> <irq> <softirq>
#    Note:  These values are total since host booted.  To give
#           usage over the interval being monitored must keep track
#           of the previous values, so that they can be subtracted for
#           this cycles count.


# Generated from /proc/stat.
#
#    User            -  Percentage of CPU utilization at the user level.
#    Nice            -  Percentage of CPU utilization at the user level with nice priority.
#    System          -  Percentage of CPU utilization at the system level.
#    Idle            -  Percentage of time the CPU is in idle state.
#    IOWait          -  Percentage of time the CPU is in idle state because an i/o operation is waiting for a disk.
#    Total           -  Total percentage of CPU utilization at user and system level.
#    New             -  Number of new processes that were produced per second.
def collectCpuInfo()

  result = Hash.new()

  file = '/proc/stat'

  if( File.exists?( file ) )

    puts 'read stats'

    File.open( file, 'r' ) do |l|

      l.each do |line|

        cpuLine = line.split[0]

        if( cpuLine.start_with?( 'cpu' ) )

          user    = line.split[1].to_i
          nice    = line.split[2].to_i
          system  = line.split[3].to_i
          idle    = line.split[4].to_i
          iowait  = line.split[5].to_i
          irq     = line.split[6].to_i
          softirq = line.split[7].to_i

          result[cpuLine] = {
            'user' => user,
            'nice' => nice,
            'system' => system,
            'idle' => idle,
            'iowait' => iowait,
            'irq'    => irq,
            'softirq' => softirq
          }
        end

      end
    end

  end

  return JSON.pretty_generate( Hash[result.sort] )

end


# Generated from /proc/stat or /proc/vmstat.
#
#    PageIn          -  Number of kilobytes the system has paged in from disk.
#    PageOut         -  Number of kilobytes the system has paged out to disk.
#    SwapIn          -  Number of kilobytes the system has swapped in from disk.
#    SwapOut         -  Number of kilobytes the system has swapped out to disk.

def collectVMStats()

 result = Hash.new()

  file = '/proc/vmstat'

  if( File.exists?( file ) )

    puts 'read vmstats'
    File.open( file, 'r' ) do |l|

#      puts l.map{|e| [e,e.end_with?(/^in$/)]}

      # select pgpgin,pgpgout,pswpin,pswpout

      l = l.select { |w| w =~ /^p[g,s][p,w](.*)[i,o](.*)$/ }

      l.each do |line|
        key, value = line.chomp.split
        result[key.tr(': _','')] = value
      end

    end

  end

  return JSON.pretty_generate( Hash[result.sort] )

end



# Field  1 -- # of reads completed
#     This is the total number of reads completed successfully.
# Field  2 -- # of reads merged, field 6 -- # of writes merged
#     Reads and writes which are adjacent to each other may be merged for
#     efficiency.  Thus two 4K reads may become one 8K read before it is
#     ultimately handed to the disk, and so it will be counted (and queued)
#     as only one I/O.  This field lets you know how often this was done.
# Field  3 -- # of sectors read
#     This is the total number of sectors read successfully.
# Field  4 -- # of milliseconds spent reading
#     This is the total number of milliseconds spent by all reads (as
#     measured from __make_request() to end_that_request_last()).
# Field  5 -- # of writes completed
#     This is the total number of writes completed successfully.
# Field  6 -- # of writes merged
#     See the description of field 2.
# Field  7 -- # of sectors written
#     This is the total number of sectors written successfully.
# Field  8 -- # of milliseconds spent writing
#     This is the total number of milliseconds spent by all writes (as
#     measured from __make_request() to end_that_request_last()).
# Field  9 -- # of I/Os currently in progress
#     The only field that should go to zero. Incremented as requests are
#     given to appropriate struct request_queue and decremented as they finish.
# Field 10 -- # of milliseconds spent doing I/Os
#     This field increases so long as field 9 is nonzero.
# Field 11 -- weighted # of milliseconds spent doing I/Os
#     This field is incremented at each I/O start, I/O completion, I/O
#     merge, or read of these stats by the number of I/Os in progress
#     (field 9) times the number of milliseconds spent doing I/O since the
#     last update of this field.  This can provide an easy measure of both
#     I/O completion time and the backlog that may be accumulating.

# Block layer disk statistics
# Field 1 – # read_IOs       # : Total number of reads completed (requests)
# Field 2 – # read_merges    # : Total number of reads merged (requests)
# Field 3 – # read_sectors   # : Total number of sectors read (sectors)
# Field 4 – # read_ticks     # : Total time spent reading (milliseconds)
# Field 5 – # write_IOs      # : Total number of writes completed (requests)
# Field 6 – # write_merges   # : Total number of writes merged (requests)
# Field 7 – # write_sectors  # : Total number of sectors written (sectors)
# Field 8 – # write_ticks    # : Total time spent writing (milliseconds)
# Field 9 – # in_flight      # : The number of I/Os currently in flight.
#                            #   It does not include I/O
#                            #   requests that are in the queue but not yet issued to the device driver. (requests)
# Field 10 – # io_ticks      # : This value counts the time during which the device has had I/O requests queued. (milliseconds)
# Field 11 – # time_in_queue # : The number of I/Os in progress (field 9) times the number
#                                of milliseconds spent doing I/O since the last update of this field. (milliseconds)

# Generated from /proc/diskstats or /proc/partitions.
#
#    Major           -  The mayor number of the disk
#    Minor           -  The minor number of the disk
#    ReadRequests    -  Number of read requests that were made to physical disk.
#    ReadBytes       -  Number of bytes that were read from physical disk.
#    WriteRequests   -  Number of write requests that were made to physical disk.
#    WriteBytes      -  Number of bytes that were written to physical disk.
#    TotalRequests   -  Total number of requests were made from/to physical disk.
#    TotalBytes      -  Total number of bytes transmitted from/to physical disk.

def collectDiskStats()

 result = Hash.new()

  file = '/proc/diskstats'

  if( File.exists?( file ) )

    puts 'read vmstats'
    File.open( file, 'r' ) do |l|

      l.each do |line|
        key, value = line.chomp.split
        result[key.tr(': _','')] = value
      end

    end

  end

  return JSON.pretty_generate( Hash[result.sort] )

end



# Generated from /proc/net/dev.
#
#    RxBytes         -  Number of bytes received.
#    RxPackets       -  Number of packets received.
#    RxErrs          -  Number of errors that happend while received packets.
#    RxDrop          -  Number of packets that were dropped.
#    RxFifo          -  Number of FIFO overruns that happend on received packets.
#    RxFrame         -  Number of carrier errors that happend on received packets.
#    RxCompr         -  Number of compressed packets received.
#    RxMulti         -  Number of multicast packets received.
#    TxBytes         -  Number of bytes transmitted.
#    TxPackets       -  Number of packets transmitted.
#    TxErrs          -  Number of errors that happend while transmitting packets.
#    TxDrop          -  Number of packets that were dropped.
#    TxFifo          -  Number of FIFO overruns that happend on transmitted packets.
#    TxColls         -  Number of collisions that were detected.
#    TxCarr          -  Number of carrier errors that happend on transmitted packets.
#    TxCompr         -  Number of compressed packets transmitted.
#
#    This are just some summaries of NetStats/NetStats().
#
#    RxBytes         -  Total number of bytes received.
#    TxBytes         -  Total number of bytes transmitted.

def collectNetDev()

 result = Hash.new()

  file = '/proc/net/dev'

  if( File.exists?( file ) )

    puts 'read net/dev'
    File.open( file, 'r' ) do |l|

      # wirf die ersten 2 zeilen weg
      l = l.each_line.drop(2)

      l.each do |line|

        puts line

        key, value = line.chomp.split
        result[key.tr(': _','')] = value
      end

    end

  end

  return JSON.pretty_generate( Hash[result.sort] )

end




# puts collectLoadAvg
# puts collectMemInfo
# puts collectCpuInfo
# puts collectVMStats

puts collectNetDev


