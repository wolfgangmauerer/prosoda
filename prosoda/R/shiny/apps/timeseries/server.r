# Copyright Siemens AG 2013
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

source("../../../dynamic_graphs/timeseries.r", chdir=TRUE, local=TRUE)

shinyServer(ml.timeseries.server)
