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
## Copyright 2013 by Siemens AG, Johannes Ebke <johannes.ebke.ext@siemens.com>
## All Rights Reserved.

## This file should contain the overview widgets for the main dashboard
source("../symbols.r", chdir=TRUE)
source("../figures.of.merit.r", chdir=TRUE)

combine.status <- function(status.list) {
  status.individual <- c(unlist(status.list))
  status.individual <- status.individual[!(as.integer(status.individual) == as.integer(status.error))]
  if (length(status.individual) == 0) {
    status.error
  } else {
    as.status(status.codes[mean(status.individual)])
  }
}

## Global status indicators for the project processing overview widget:
symbols.processing.status <- symbols.weather

## Global status indicators for the project status widget:
symbols.project.status <- symbols.emotion

as.color <- function(status) {
  status.codes.colors[[which(status.codes == status)]]
}

good.warn.bad.if <- function(x, good.limit, warn.limit, err.limit=0) {
  if (x > good.limit) {
    status.good
  } else if (x > warn.limit) {
    status.warn
  } else if (x > err.limit) {
    status.bad
  } else {
    status.error
  }
}

text.enumerate <- function(lst) {
  l <- length(lst)
  if (l == 0) {
    return("")
  } else if (l == 1) {
    return(as.character(lst[[1]]))
  } else {
    paste(do.call(function(...) { paste(..., sep=", ") }, as.list(lst[1:l-1])), "and", lst[l])
  }
}

## Provide a round status indicator with the given background color
## and containing the specified symbol.
make.indicator <- function(symbol, color) {
  div(style=paste("margin: auto; ", "width: 50px; ", "height: 50px;",
                  " -webkit-border-radius: 25px;",
                  "-moz-border-radius: 25px;",
                  "border-radius: 25px;",
                  #"border-width:0.1px; border-style:solid; border-color:black;",
                  "box-shadow: 2px 2px 2.5px rgb(0,0,0);",
                  "line-height: 50px; text-align: center; vertical-align: middle;",
                  "font-size: 30px;",
                  "background-color:", color, ";"),
                  symbol)
}


## Return HTML for an overview box
overview.html <- function(title, bigtext, subtitle, link, subtitle.size="100%") {
  tagList(
    tags$div(class="grid_title", title),
    tags$div(class='grid_bigtext', style="font-size:120px; line-height: 80px; text-align: center", bigtext),
    tags$div(style=paste("font-size:", subtitle.size, "; text-align: center; font-size: 60px; line-height: 40px; margin-top: 25px"), subtitle)
  )
}

## Superclass constructor which already fills important variables
initWidget.widget.overview <- function(w) {
  # Call superclass
  w <- NextMethod(w)
  w$project.name <- reactive({query.project.name(conf$con, w$pid())})
  w$cycles <- reactive({get.cycles.con(conf$con, w$pid())})
  w$data <- reactive({
    pid <- w$pid()
    cycles <- w$cycles()
    list(
      n.commits = dbGetQuery(conf$con, str_c("SELECT COUNT(*) FROM commit WHERE projectId=", pid))[[1]],
      n.persons = dbGetQuery(conf$con, str_c("SELECT COUNT(*) FROM person WHERE projectId=", pid))[[1]],
      n.tsplots = dbGetQuery(conf$con, str_c("SELECT COUNT(*) FROM plots WHERE name LIKE 'Progress%' AND projectId=", pid))[[1]],
      n.issues = dbGetQuery(conf$con, str_c("SELECT COUNT(*) FROM issue WHERE projectId=", pid))[[1]],
      n.mail.threads = dbGetQuery(conf$con, str_c("SELECT COUNT(*) FROM mail_thread WHERE projectId=", pid))[[1]],
      n.understand.plots = dbGetQuery(conf$con, str_c("SELECT COUNT(*) FROM plots WHERE name LIKE 'Understand%' AND projectId=", pid))[[1]]
    )
  })
  return(w)
}

## Widget which presents a processing overview for prosoda operators
createWidgetClass(
  c("widget.overview.processing", "widget.overview"),
  "Project Processing Status", "Short, one-widget project processing status",
  c("invisible"),
  1, 1,
  html=htmlOutput,
  detailpage=list()
)

initWidget.widget.overview.processing <- function(w) {
  # Call superclass
  w <- NextMethod(w)
  w$status <- reactive({
    list(
      commits = good.warn.bad.if(w$data()$n.commits, 100, 10),
      timeseries = if (w$data()$n.tsplots > 0) { status.good } else { status.bad },
      issues = good.warn.bad.if(w$data()$n.issues, 10, 0),
      ml = good.warn.bad.if(w$data()$n.mail.threads, 100, 10),
      complexity = good.warn.bad.if(w$data()$n.understand.plots, 1, 0)
    )
  })
  return(w)
}

renderWidget.widget.overview.processing <- function(w) {
  renderUI({
    ## Take minimum status as combined status
    combined.status <- status.codes[mean(c(unlist(w$status())))]
    indicator.summary <- symbols.processing.status[[which(names(symbols.processing.status) == combined.status)]]

    indicator.commits <- make.indicator(symbol.commit, as.color(w$status()$commits))
    indicator.timeseries <- make.indicator(symbol.timeseries, as.color(w$status()$timeseries))
    indicator.issues <- make.indicator(symbol.bug, as.color(w$status()$issues))
    indicator.ml <- make.indicator(symbol.email, as.color(w$status()$ml))
    indicator.complexity <- make.indicator(symbol.analysis, as.color(w$status()$complexity))

    link <- paste("?projectid=", w$pid(), sep="")
    overview.html(w$project.name(), indicator.summary,
              tags$table(width="100%", tags$tr(
                                 tags$td(indicator.commits),
                                 tags$td(indicator.timeseries),
                                 tags$td(indicator.issues),
                                 tags$td(indicator.ml),
                                 tags$td(indicator.complexity)
                                 )),
              link
    )
  })
}

widgetColor.widget.overview.processing <- function(w) {
  ## Also consider errors as "bad"
  reactive({as.color(status.codes[mean(c(unlist(w$status())))])})
}


## Widget which creates an overview of a project for analysts
createWidgetClass(
  c("widget.overview.project", "widget.overview"),
  "Project Summary", "Short, one-widget project summary",
  NULL, # no topical restrictions
  1, 1,
  html=htmlOutput,
  detailpage=list(app="dashboard", topic="overview")
)

initWidget.widget.overview.project <- function(w) {
  # Call superclass
  w <- NextMethod(w)
  w$status <- reactive({
    list(
      collaboration = figure.of.merit.collaboration(w$pid())$status,
      construction = figure.of.merit.construction(w$pid())$status,
      communication = figure.of.merit.communication(w$pid())$status,
      complexity = figure.of.merit.complexity(w$pid())$status
    )
  })
  return(w)
}

renderWidget.widget.overview.project <- function(w) {
  renderUI({
    ## Collaboration indicator color
    combined.status <- as.character(combine.status(w$status()))
    indicator.summary <- symbols.processing.status[[which(names(symbols.processing.status) == combined.status)]]

    indicator.collaboration <- make.indicator(symbol.collaboration, as.color(w$status()$collaboration))
    indicator.construction <- make.indicator(symbol.construction, as.color(w$status()$construction))
    indicator.communication <- make.indicator(symbol.communication, as.color(w$status()$communication))
    indicator.complexity <- make.indicator(symbol.complexity, as.color(w$status()$complexity))

    link <- paste("?projectid=", w$pid(), sep="")
    overview.html(w$project.name(), indicator.summary,
              tags$table(width="100%", tags$tr(
                                 tags$td(indicator.collaboration),
                                 tags$td(indicator.construction),
                                 tags$td(indicator.communication),
                                 tags$td(indicator.complexity)
                                 )),
              link
    )
  })
}

widgetColor.widget.overview.project <- function(w) {
  reactive({
    color.neutral
  })
}

widgetExplanation.widget.overview.project <- function(w) {
  reactive({
    print("--------------------")
    cs <- combine.status(w$status())
    error <- names(w$status()[w$status() == as.integer(status.error)])
    good <- names(w$status()[w$status() == as.integer(status.good)])
    warn <- names(w$status()[w$status() == as.integer(status.warn)])
    bad <- names(w$status()[w$status() == as.integer(status.bad)])
    if (all(w$status() == status.good)) {
      return("This project has good marks in all categories and is fully analysed.")
    }
    res <- list()
    if (length(good) > 0) {
      res <- c(res, paste("This project has good marks in ", text.enumerate(good), ".", sep=""))
    }
    if (length(warn) > 0) {
      res <- c(res, paste("Warnings have been reported for ", text.enumerate(warn), ".", sep=""))
    }
    if (length(bad) > 0) {
      res <- c(res, paste("There seem to be problems in ", text.enumerate(bad), ".", sep=""))
    }
    if (length(error) > 0) {
      res <- c(res, paste("No analysis has been done for ", text.enumerate(error), ".", sep=""))
    }
    res <- c(res, "Click 'details...' to get more information on the evaluations.")
    do.call(paste, res)
  })
}

# weather, emotion, animals, abstract, gestures, arrows

createWidgetClass(
  c("widget.overview.communication", "widget.overview.topic"),
  "Communication", "Information on how developers communicate",
  c("overview", "communication"),
  1, 1,
  html=htmlOutput,
  detailpage=list(app="dashboard", topic="communication")
)

createWidgetClass(
  c("widget.overview.collaboration", "widget.overview.topic"),
  "Collaboration", "Information on how developers collaborate",
  c("overview", "collaboration"),
  1, 1,
  html=htmlOutput,
  detailpage=list(app="dashboard", topic="collaboration")
)

createWidgetClass(
  c("widget.overview.complexity", "widget.overview.topic"),
  "Complexity", "Information on code complexity",
  c("overview", "complexity"),
  1, 1,
  html=htmlOutput,
  detailpage=list(app="dashboard", topic="complexity")
)

createWidgetClass(
  c("widget.overview.construction", "widget.overview.topic"),
  "Construction", "Information on the construction and architecture of the project",
  c("overview", "construction"),
  1, 1,
  html=htmlOutput,
  detailpage=list(app="dashboard", topic="construction")
)

initWidget.widget.overview.communication <- function(w) {
  # Call superclass
  w <- NextMethod(w)
  w$figure.of.merit <- reactive({ figure.of.merit.communication(w$pid()) })
  w$symbol <- symbol.communication
  w$symbols <- symbols.emotion
  w$link <- reactive({ paste("?topic=communication&projectid=", w$pid(), sep="") })
  w$status <- reactive({ w$figure.of.merit()$status })
  return(w)
}

initWidget.widget.overview.collaboration <- function(w) {
  # Call superclass
  w <- NextMethod(w)
  w$figure.of.merit <- reactive({ figure.of.merit.collaboration(w$pid()) })
  w$symbol <- symbol.collaboration
  w$symbols <- symbols.gestures
  w$link <- reactive({ paste("?topic=collaboration&projectid=", w$pid(), sep="") })
  w$status <- reactive({ w$figure.of.merit()$status })
  return(w)
}

initWidget.widget.overview.construction <- function(w) {
  # Call superclass
  w <- NextMethod(w)
  w$figure.of.merit <- reactive({ figure.of.merit.construction(w$pid()) })
  w$symbol <- symbol.construction
  w$symbols <- symbols.abstract
  w$link <- reactive({ paste("?topic=construction&projectid=", w$pid(), sep="") })
  w$status <- reactive({ w$figure.of.merit()$status })
  return(w)
}

initWidget.widget.overview.complexity <- function(w) {
  # Call superclass
  w <- NextMethod(w)
  w$figure.of.merit <- reactive({ figure.of.merit.complexity(w$pid()) })
  w$symbol <- symbol.complexity
  w$symbols <- symbols.arrows.up.is.bad
  w$link <- reactive({ paste("?topic=complexity&projectid=", w$pid(), sep="") })
  w$status <- reactive({ w$figure.of.merit()$status })
  return(w)
}

renderWidget.widget.overview.topic <- function(w) {
  #reactive({list(text=intToUtf8(0x2197), subtext="++")})
  renderUI({
    status.symbol <- w$symbols[[which(names(w$symbols) == w$status())]]
    overview.html(w$name, status.symbol, w$symbol, w$link(), "400%")
  })
}

widgetColor.widget.overview.topic <- function(w) {
  reactive({
    ## Collaboration indicator color
    combined.status <- status.codes[w$status()]
    as.color(combined.status)
  })
}

widgetExplanation.widget.overview.topic <- function(w) {
  reactive({
    w$figure.of.merit()$why
  })
}

