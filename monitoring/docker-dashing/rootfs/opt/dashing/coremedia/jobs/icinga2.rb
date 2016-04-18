
#/******************************************************************************
# * Icinga 2 Dashing Job                                                       *
# * Copyright (C) 2015 Icinga Development Team (https://www.icinga.org)        *
# *                                                                            *
# * This program is free software; you can redistribute it and/or              *
# * modify it under the terms of the GNU General Public License                *
# * as published by the Free Software Foundation; either version 2             *
# * of the License, or (at your option) any later version.                     *
# *                                                                            *
# * This program is distributed in the hope that it will be useful,            *
# * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
# * GNU General Public License for more details.                               *
# *                                                                            *
# * You should have received a copy of the GNU General Public License          *
# * along with this program; if not, write to the Free Software Foundation     *
# * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.             *
# ******************************************************************************/

require './lib/icinga2'

icinga = Icinga2.new( 'config/icinga2.json' )


SCHEDULER.every '30s' do

  icinga.run

  send_event( 'icinga-uptime', {
    value: icinga.uptime,
    color: 'blue' }
  )

  send_event( 'icinga-version', {
    value: icinga.version,
    color: 'blue' }
  )

#   send_event( 'icinga-hosts-latest', {
#     rows: result["latest"],
#     moreinfo: result["latest_moreinfo"]
#   })

  # icinga-hosts-latest


  puts " ----------------------------- "

  puts "uptime      : " + icinga.uptime.to_s
  puts "services ok : " + icinga.services_ok.to_s
  puts "hosts up    : " + icinga.hosts_up.to_s
  puts "hosts down  : " + icinga.hosts_down.to_s

  puts " ----------------------------- "

end

