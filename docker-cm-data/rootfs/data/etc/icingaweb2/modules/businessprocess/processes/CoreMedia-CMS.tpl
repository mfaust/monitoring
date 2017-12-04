### Business Process Config File ###
#
# Title           : CMS
# Owner           : icinga
# AddToMenu       : yes
# Backend         : icinga
# Statetype       : soft
#
###################################

IOR = %HOSTNAME%;IOR-content_management_server
LICENSE = %HOSTNAME%;License-content_management_server
DATABASE = %HOSTNAME%;port-mysql

CMS  = IOR & LICENSE & DATABASE

display 1;CMS;CMS
