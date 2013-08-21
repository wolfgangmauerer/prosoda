#! /usr/bin/env Rscript

## This file is part of prosoda.  prosoda is free software: you can
## redistribute it and/or modify it under the terms of the GNU General Public
## License as published by the Free Software Foundation, version 2.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##
## Copyright 2013 by Siemens AG, Wolfgang Mauerer <wolfgang.mauerer@siemens.com>
## All Rights Reserved.

source("../common.server.r", chdir=TRUE)
source("../../widgets/contributors.r", chdir=TRUE)

shinyServer(function(input, output, clientData, session) {
  pid = common.server.init(output, session, "contributors")

  observe({
    range.ids.list <- query.range.ids.con(conf$con, pid())
    cycles <- reactive({get.cycles.con(conf$con, pid())})
    names(range.ids.list) <- cycles()$cycle
    updateSelectInput(session, "cycle", choices=range.ids.list)
  })

  range.id <- reactive({input$cycle})

  output$prTable <- contributors.table.pagerank(pid, range.id)
  output$prTrTable <- contributors.table.pagerank.transposed(pid, range.id)
  output$commitsTable <- contributors.table.commits(pid, range.id)
  output$changesTable <- contributors.table.changes(pid, range.id)
  output$quantarchContent <- renderUI({
    pageWithSidebar(
      headerPanel("Contributors"),
      sidebarPanel(
        selectInput("cycle", "Release Cycle", choices = list(1)),
        helpText(paste("Interpretational aid: Page rank focuses on giving tags, ",
                       "transposed page rank on being tagged."))
      ),
      mainPanel(
        tabsetPanel(
          tabPanel("Page Rank", tableOutput("prTable")),
          tabPanel("Page Rank (tr)", tableOutput("prTrTable")),
          tabPanel("Commits", tableOutput("commitsTable")),
          tabPanel("Code Changes", tableOutput("changesTable"))
        )
      )
    )
  })
})
