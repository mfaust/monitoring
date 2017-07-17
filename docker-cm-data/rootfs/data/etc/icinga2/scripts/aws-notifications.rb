#!/usr/bin/env ruby

require 'logger'

@aws_region         = ENV.fetch('AWS_REGION'        , 'us-east-1')
@aws_sns_account_id = ENV.fetch('AWS_SNS_ACCOUNT_ID', nil)
@aws_sns_topic      = ENV.fetch('AWS_SNS_TOPIC'     , nil)
@icingaweb_url      = ENV.fetch('ICINGAWEB_URL'     , 'https://icinga2/icingaweb2')

# -----------------------------------------------------------------------------

logFile         = '/tmp/notification.log'
file            = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
file.sync       = true
@logger         = Logger.new( file, 'weekly', 1024000 )

@logger.level           = Logger::DEBUG
@logger.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
@logger.formatter       = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime( @logger.datetime_format )}] #{severity.ljust(5)} : #{msg}\n"
end

# -----------------------------------------------------------------------------

def environments

  ENV["HOSTNAME"] = "icinga2-master"
  ENV["HOSTADDRESS"] = "blueprint-box"
  ENV["HOSTDISPLAYNAME"] = "blueprint-box"
  ENV["HOSTNAME"] = "blueprint-box"
  ENV["LASTCHECK"] = "1500293636"
  ENV["LASTSTATE"] = "CRITICAL"
  ENV["LASTSTATETYPE"] = "HARD"
  ENV["NOTIFICATIONAUTHORNAME"] = "icinga"
  ENV["NOTIFICATIONCOMMENT"] = "force"
  ENV["NOTIFICATIONTYPE"] = "CUSTOM"
  ENV["SERVICEDISPLAYNAME"] = "CoreMedia - CAEFeeder - live"
  ENV["SERVICEDURATION"] = "2903.200815"
  ENV["SERVICENAME"] = "CAEFeeder-caefeeder_live"
  ENV["SERVICEOUTPUT"] = "CRITICAL - no data found - service not running!?"
  ENV["SERVICEPERFDATA"] = ""
  ENV["SERVICESTATE"] = "CRITICAL"
  ENV["SERVICESTATETYPE"] = "HARD"

end


def sns
  @sns = Aws::SNS::Client.new( region: @aws_region )
end


def create_message

#   @logger.debug ENV.to_a

  notification_type = ENV.fetch('NOTIFICATIONTYPE',nil)

  host_name = ENV.fetch('HOSTNAME',nil)
  host_address = ENV.fetch('HOSTADDRESS',nil)
  host_display_name = ENV.fetch('HOSTDISPLAYNAME',nil)

  service_name = ENV.fetch('SERVICENAME',nil)

  last_check = ENV.fetch('LASTCHECK',nil)
  last_state = ENV.fetch('LASTSTATE',nil)
  last_state_type = ENV.fetch('LASTSTATETYPE',nil)

  comment = nil
  author = nil

  subject = format(
    '%s - %s',
    notification_type,
    host_name
  )

  if( notification_type == 'ACKNOWLEDGEMENT' )

    author  = ENV.fetch('NOTIFICATIONAUTHORNAME',nil)
    comment = ENV.fetch('NOTIFICATIONCOMMENT',nil)
  end

  if( service_name )

    state                 = ENV.fetch('SERVICESTATE',nil)
    service_display_name  = ENV.fetch('SERVICEDISPLAYNAME',nil)
    service_state_type    = ENV.fetch('SERVICESTATETYPE',nil)
    duration      = ENV.fetch('SERVICEDURATION',nil)
    service_perf_data     = ENV.fetch('SERVICEPERFDATA',nil)
    service_output        = ENV.fetch('SERVICEOUTPUT',nil)

    details_url = format(
      '%s/monitoring/service/show?host=%s&service=%s',
      @icingaweb_url,
      host_name,
      service_name
    )

    ack_url = format(
      '%s/monitoring/service/acknowledge-problem?host=%s&service=%s',
      @icingaweb_url,
      host_name,
      service_name
    )

    subject = format(
      '%s / %s',
      subject,
      service_display_name
    )

  else

    state           = ENV.fetch('HOSTSTATE',nil)
    host_state_type = ENV.fetch('HOSTSTATETYPE',nil)
    host_output     = ENV.fetch('HOSTOUTPUT',nil)
    duration   = ENV.fetch('HOSTDURATION',nil)
    host_perfdata   = ENV.fetch('HOSTPERFDATA',nil)

    details_url = format(
      '%s/monitoring/host/show?host=%s',
      @icingaweb_url,
      host_name
    )

    ack_url = format(
      '%s/monitoring/host/acknowledge-problem?host=%s',
      @icingaweb_url,
      host_name
    )

  end

  failed_since = Time.at(duration.to_f).strftime('%H:%M:%S')

  last_check_datetime = Time.at(last_check.to_f)
  last_check = last_check_datetime.strftime('%F %H:%M:%S %Z')

  problem_time_datetime = Time.now().to_i - Time.at( duration.to_i ).to_i
  problem_time = Time.at(problem_time_datetime).strftime('%F %H:%M:%S %Z')

  subject = format(
    '%s : %s',
    state, subject

  )

  body_text = format(
    '***** Icinga2 %s Notification ******

  Host:              %s (%s)
  Last Check:        %s
  Duration:          %s hours (since %s)
  ',
    notification_type.capitalize,
    host_name,
    host_address,
    last_check,
    failed_since,
    problem_time
  )

    if( notification_type == 'ACKNOWLEDGEMENT' )
      body_text += format(
        '
  Comment:           %s
  Author:            %s',
    comment,
    author
  )

    end

    body_text += format('
  Show Details:      %s',
    details_url=details_url
    )

    if( ['RECOVERY', 'DOWNTIME', 'FLAPPINGSTART', 'FLAPPINGEND'].include?(notification_type) )
      body_text += format('
  Acknowledge:       %s
    ',
    ack_url=ack_url,
    )
    end

  [subject,body_text]

#  @logger.debug body_text

end


def publish( params = {} )

  subject = params.dig(:subject)  || 'This is a test subject'
  message = params.dig(:body)     || 'This is a test message'

  topic_arn = sprintf( 'arn:aws:sns:%s:%s:%s', @aws_region, @aws_sns_account_id, @aws_sns_topic )

  @logger.debug( subject )
  @logger.debug( message )
  @logger.debug(topic_arn)

  resp = sns.publish(
    topic_arn: topic_arn,
    subject: subject,
    message: message
  )

  @logger.debug(resp)

end

# environments

subject, body = create_message

publish( subject: subject, body: body )

# -----------------------------------------------------------------------------

