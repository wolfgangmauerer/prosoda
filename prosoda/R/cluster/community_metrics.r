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
## Copyright 2012, 2013, Siemens AG, Mitchell Joblin <mitchell.joblin.ext@siemens.com>
## All Rights Reserved.
##
## File Description:
##  Various measures and test for the significance and quality of a community
##  or cluster in a graph structure

edge.weight.to.multi <- function(g) {
  ## Converters an edge weight to multiple edges between the connected nodes
  ## Args:
  ##	g: igraph graph object
  ## Returns:
  ##	g.multi: igraph graph object with multiple edges and non-weighted edges
  mult.edges <- c()
  mult.edges <-unlist(mapply(function(x.1,x.2,w) rep(c(x.1,x.2), times=w-1),
                      get.edgelist(g)[,1], get.edgelist(g)[,2],
                      E(g)$weight))
  g.multi <- add.edges(g, mult.edges)
  return(g.multi)
}
##############################################
## Based on the idea of modularization
## Reference: Social network clustering and visualization using hierarchical
##			edge bundles (Jia, Garland, Hart)
###############################################
community.quality.modularization <- function(graph, community.vertices,
                                             membership.vec) {
  ## Get graph composed solely of vertices belonging to the community
  subgraph <- induced.subgraph(graph, community.vertices)

  ## Get all vertices not belonging to the community
  not.community.vertices <- setdiff(V(graph), community.vertices)

  ## Measure the degree for intra-community edges
  intra.degree.sum <- sum(degree(subgraph))

  ## Get number of vertices within the subgraphs
  cluster.vcount     <- vcount(subgraph)
  ##not.cluster.vcount <- length(not.community.vertices)

  ## Degree of vertices in community
  community.vertices.degree <- degree(graph, community.vertices)

  ## Degree of vertices external to community
  community.vertices.degree.sum <- sum( degree(graph, community.vertices) )

  extern.edges.sum <- community.vertices.degree.sum - intra.degree.sum

  ## Find membership of other vertices
  other.clusters <- membership.vec[not.community.vertices]

  cluster.id <- unique(other.clusters)

  cluster.size <- sapply(cluster.id,
                         function(x) {return(length(which(x == other.clusters)))})

  edges.count <- sapply(cluster.id,
			function(x) {
                          res <- sum(graph[community.vertices,
                                           which(x == membership.vec)]) +
                                 sum(graph[which(x == membership.vec),
                                           community.vertices])
                          return(res)
                        })

  edge.count.div <- edges.count / (2*(cluster.size*cluster.vcount))
  ## Divide by two to get the value of the intra edges,
  ## degree will count edges twice, once for each node connected
  ##  by the edge
  intra.edges.sum <- intra.degree.sum / 2

  ## Get number of clusters
  num.of.clusters <- length(unique(membership.vec))

  f.1 <- (1/num.of.clusters) * intra.edges.sum / (cluster.vcount)^2
  f.2 <- (1/( ((num.of.clusters)*(num.of.clusters-1)) / 2)) * (sum(edge.count.div) )

  return (f.1 - f.2)

}


#######################################
## Finds the conductance of a cluster
#######################################
community.quality.conductance <- function(graph, community.vertices) {
  ## Get graph composed solely of vertices belonging to the community
  cluster.subgraph <- induced.subgraph(graph, community.vertices)

  ## get weighted degree for subgraphs
  intra.degree <- graph.strength(cluster.subgraph, mode="all")

  ## degree of vertices in community
  community.vertices.degree <- graph.strength(graph, community.vertices,
											  mode="all")

  ## sum all degrees from vertices
  community.vertices.degree.total  <- sum(community.vertices.degree)
  intra.degree.total               <- sum(intra.degree)

  ## edge sum of edges that cross
  inter.edge.sum <- community.vertices.degree.total - intra.degree.total

  return(inter.edge.sum / community.vertices.degree.total)
}

community.quality.wilcox <- function (graph, community.vertices) {
  ## Get graph composed solely of vertices belonging to the community
  subgraph <- induced.subgraph(graph, community.vertices)

  ## Measure the degree for intra-community edges
  intra.degree <- degree(subgraph)

  ## Degree of vertices in community
  community.vertices.degree <- degree(graph, community.vertices)

  ## Measure the degree for inter-community edges
  inter.degree <- community.vertices.degree - intra.degree

  ## significance <- wilcox.test(jitter(intra.degree), jitter(inter.degree))

                                        #return(significance$p.value)
  sig <- (sum(intra.degree) / (sum(inter.degree) + sum(intra.degree)))

  return(sig)
}


######################################################################
## Measure the based on modularity calculation
## quality of the a community indicated by a set of vertices
## that belong to the community in comparison to the rest of the graph
## Reference:
## "On Modularity Clustering," Knowledge and Data Engineering,
## IEEE Transactions on , vol.20, no.2, pp.172-188, Feb. 2008
######################################################################
community.quality.modularity <- function(graph, community.vertices) {
  ## Get graph composed solely of vertices belonging to the community
  subgraph <- induced.subgraph(graph, community.vertices)

  ## Number of edges interal to community
  community.num.edges = sum(graph.strength(subgraph, mode="all")) / 2
  ## Total number of edge is graph
  m = sum(graph.strength(graph, mode="all")) / 2

  ## Measure the degree for intra-community edges
  intra.degree <- degree(subgraph)

  ## Degree of vertices in community
  community.vertices.degree <- graph.strength(graph, community.vertices, mode="all")

  ## Calculate final result
  f.1 <- community.num.edges / m
  f.2 <- (sum(community.vertices.degree) / (2*m) )^2
  quality  <- f.1 - f.2
  return(quality)
}

############################################################################
## Computer the statistical significance of community structure for a given
## graph. The graph structure is compared to the community structure
## probability density of the randomized version of the graph. The
## randomization procedure maintains the degree distributions of the original
## graph.
## - Input -
## graph: original graph for which we would like to find the statistical
##        significance of community structure
## cluster.algo: clustering algorithm used to find communities
## - Output -
## p-value: the result of the statistical significance test
############################################################################
community.stat.significance <- function(graph, cluster.algo) {
  ## extract clusters
  graph.clusters <- community.detection.disconnected(graph, cluster.algo)

  ## compute cluster conductance values
  cluster.conductance <- community.metric(graph, graph.clusters,
                                          "conductance")
  cluster.conductance <- cluster.conductance[!is.na(cluster.conductance)]
  ## compute randomized conductance samples
  niter <- 2
  rand.samps <- randomised.conductance.samples(graph, niter, cluster.algo)

  ## test for normality
  ## check if values are same because the test while fail if they are 
  if( length(unique(rand.samps) == 1)){
    normality.test <- c()
    normality.test$p.value <- -1
  } else {
    normality.test <- shapiro.test(rand.samps)
  }

  ## compute normal distribution
  mean.conductance <- mean(rand.samps)
  sd.conductance   <- sd  (rand.samps)

  ## perform t-test on test statistic
  t.test.result <- t.test(rand.samps,  mu=mean(cluster.conductance))

  ## output result
  save.comm.sig.test(rand.samps, cluster.conductance,t.test.result,
                     normality.test, outfile, format="png")
}


## write the significance test results to pdf
save.comm.sig.test <- function(rand.samps, cluster.conductance,t.result, 
                               shap.result, outfile, size=7, format="png") {
	m.c = sum(cluster.conductance)
	m.r = mean(rand.samps)
	s.r = sd(rand.samps)
	x.low.lim <- 0
	x.up.lim  <- 1
	x.lim = c(x.low.lim, x.up.lim)
  select.graphics.dev(filename=outfile, size=size, format=format)
	plot(density(rand.samps), main="Community Significance Test", ylab="Probability Density", xlab="Conductance", xlim=x.lim)
	points(x=mean(cluster.conductance),y=0, col="green", pch=21, cex=2.5, bg="green")
	abline(v=t.result$conf.int[1], col='red')
	#abline(v=t.result$estimate, col='black')
	abline(v=t.result$conf.int[2], col='red')
	legendData <- character(2)
	legendData[1] <- sprintf("T-test p-value: %e", t.result$p.value)
	legendData[2] <- sprintf("Shapiro-Wilk p-value: %e", shap.result$p.value)
	legend("topleft", legend=legendData, bty="n")
	dev.off()
}


############################################################################
## Randomize a given graph while maintaining the degree distribution using
## a rewiring concept. For each randomized graph a decomposition is performed
## and the conductance is measured for each trial and is saved.
## - Input -
## graph: an igraph object that is to be randomized
## niter: the number of iterations in randomizing and measuring conductance
## cluster.algo: clustering algorithm used to find communities
## - Ouput -
## conduct.vec: the conductance for each trial
############################################################################
randomised.conductance.samples <- function(graph, niter, cluster.algo) {
  ## Check if loops exist in the original graph, this information is necessary
  ## to choose the appropriate rewiring strategy
  loops.exist <- any(is.loop(graph))
  if (loops.exist) {
    rewire.mode = "loops"
  }
  else {
    rewire.mode = "simple"
  }

  ## Perform iterations
  conduct.vec <- vector()
  graph.multi <- edge.weight.to.multi(graph)
  pb <- txtProgressBar(min = 0, max = niter, style = 3)
  for (i in 1:niter) {
    ## Update progress bar
    setTxtProgressBar(pb, i)

    ## Rewire graph, randomize the graph while maintaining the degree distribution
    #rw.graph <- rewire(graph.multi, mode = rewire.mode,
    #                              niter = 1)#10*ecount(graph.multi))
    rw.graph <- degree.sequence.game(igraph::degree(graph.multi, mode="all"))

    E(rw.graph)$weight <- 1
    rw.graph <- simplify(rw.graph, remove.loops=FALSE)

    ## Find clusters
    rw.graph.clusters <- community.detection.disconnected(rw.graph, cluster.algo)

    ## Only analyze clusters that are large than 10 vertices
    ##rw.graph.clusters.more <- select.communities.more(rw.graph.clusters, 10)

    ## Compute conductance
    rw.cluster.conductance <- community.metric(rw.graph, rw.graph.clusters,
                                               "conductance")
    conduct.vec <- append(conduct.vec, mean(rw.cluster.conductance, na.rm=TRUE))
  }
  ## Close progress bar
  close(pb)

  return(conduct.vec)
}


########################################################################
##Input:
##   - graph, igraph object

##   - community, community object that indicates how vertices in graph are
##		belonging to a community, must contain csize and
##		membership attributes these are standard attributes
##		for community dectection algorithms in
##
##       igraph
## Output:
##   - vector of metric values indexed by community number
########################################################################
community.metric <- function(graph, community, test) {
  ## Get number of communities
  if (class(community) == "communities") {
    community.id <- sort(unique(community$membership))
    members <- sapply(community.id,
                      function(x) {
                        return(list(which(community$membership==x)))
                      })
  }
  else if (class(community) == "overlapComm") {
    community.id <- 1:length(community$csize)
    members <- community
  }

  if(test == "modularity") {
    metric.vec <- sapply(community.id,
                          function(x) {
                            return(community.quality.modularity(graph, members[[x]]))
                          })
  }
  else if (test == "wilcox") {
    metric.vec <- sapply(community.id,
                          function(x) {
                            return(community.quality.wilcox(graph, members[[x]]))})
  }
  else if (test == "conductance") {
    metric.vec <- sapply(community.id,
                          function(x) {
                            return(community.quality.conductance(graph, members[[x]]))
                          })

  }
  else if (test == "modularization") {
    metric.vec <- sapply(community.id,
                          function(x) {
                            return(community.quality.modularization(graph,
                                            members[[x]], community$membership))
                          })
  }
  else if (test == "betweenness") {
    metric.vec <- sapply(community.id,
                          function(x) {
                            g.sub <- induced.subgraph(graph, members[[x]])
                            return(betweenness(g.sub))
                          })
  }
  else if(test == "transitivity") {
    metric.vec <- sapply(community.id,
                           function(x) {
                             g.sub <- induced.subgraph(graph, members[[x]])
                             return (transitivity(g.sub,type="local"))
                           })
  }
  else if(test == "out.weight") {
    metric.vec <- sapply(community.id,
        function(x) {
          g.sub <- induced.subgraph(graph, members[[x]])
          return (graph.strength(g.sub, mode="out"))
        })
  }
  else if(test == "in.weight") {
    metric.vec <- sapply(community.id,
        function(x) {
          g.sub <- induced.subgraph(graph, members[[x]])
          return (graph.strength(g.sub, mode="in"))
        })
  }
  else if(test == "out.deg") {
    metric.vec <- sapply(community.id,
        function(x) {
          g.sub <- induced.subgraph(graph, members[[x]])
          return (igraph::degree(g.sub, mode="out"))
        })
  }
  else if(test == "in.deg") {
    metric.vec <- sapply(community.id,
        function(x) {
          g.sub <- induced.subgraph(graph, members[[x]])
          return (igraph::degree(g.sub, mode="in"))
        })
  }
  else if(test == "diameter") {
    metric.vec <- sapply(community.id,
        function(x) {
          g.sub <- induced.subgraph(graph, members[[x]])
          return (diameter(g.sub))
        })
  }

  return(metric.vec)
}


## Compute SNA metrics using community centric perspective
## ARGS:
##  g: igraph graph object
##  comm: igraph communities object
## RETURNS:
##  res: list containing all statistics
compute.community.metrics <- function(g, comm) {
  res <- list()

  ## intra-community
  res$intra.betweenness  <- community.metric(g, comm,
      "betweenness")
  res$intra.transitivity <- community.metric(g, comm,
      "transitivity")
  res$intra.in.deg     <- community.metric(g, comm, "in.deg")
  res$intra.out.deg    <- community.metric(g, comm, "out.deg")
  res$intra.in.weight  <- community.metric(g, comm, "in.weight")
  res$intra.out.weight <- community.metric(g, comm, "out.weight")
  res$intra.diameter   <- community.metric(g, comm, "diameter")
  ## inter-community
  g.con     <- contract.vertices(g, membership(comm), vertex.attr.comb=toString)
  g.con.sim <- simplify(g.con)
  res$inter.betweeness   <- betweenness(g.con.sim)
  res$inter.transitivity <- transitivity(g.con.sim, type="local")
  res$inter.in.deg       <- degree(g.con.sim, mode="in")
  res$inter.out.deg      <- degree(g.con.sim, mode="out")
  res$inter.in.weight    <- graph.strength(g.con.sim, mode="in")
  res$inter.out.weight   <- graph.strength(g.con.sim, mode="out")
  res$inter.diameter     <- diameter(g.con.sim)
  res$num.comms          <- vcount(g.con.sim)
  ## quality
  res$conductance <- community.metric(g, comm, "conductance")
  res$mean.conductance <- mean(res$conductance, na.rm=TRUE)
  res$sd.conductance <- sd(res$conductance, na.rm=TRUE)
  res$modularity     <- modularity(g, comm$membership)

  ## global
  res$mean.size <- mean(comm$csize)
  res$sd.size   <- sd(comm$csize)
  res$max.size  <- max(comm$csize)
  intra.edges   <- unlist(lapply(res$intra.in.deg,sum))
  res$mean.num.edges <- mean(intra.edges)
  res$sd.num.edges   <- sd(intra.edges)
  res$max.edges <- max(intra.edges)
  res$vcount    <- vcount(g)
  return(res)
}


generate.community.tables <- function(con, cluster.method, analysis.method) {
  projects   <- query.projects(con, analysis.method)
  range.data <- lapply(projects$id, function(p.id) get.cycles.con(con, p.id))
  metrics.df <- data.frame()

  for(i in 1:nrow(projects)) {
    p.id <- projects$id[i]
    p.range.ids   <- range.data[[i]]$range.id
    p.range.names <- range.data[[i]]$cycle
    graph.data <- lapply(p.range.ids, function(r.id)
          get.graph.data.local(con, p.id, r.id, cluster.method))
    graph <- lapply(graph.data,
        function(x) {
          graph.data.frame(x$edgelist, directed=TRUE,
              vertices=data.frame(x$v.local.ids))})

    ## Compute community metrics
    idx <- 1:length(p.range.ids)
    graph.comm <- lapply(idx, function(j) minCommGraph(graph[[j]],
              graph.data[[j]]$comm, min=4))
    comm.stats <- lapply(idx, function(j)
          compute.community.metrics(graph.comm[[j]]$graph,
              graph.comm[[j]]$community))
    comm.stat.rows <- lapply(idx, function(j) {
          comm.stats[[j]]$p.id <- p.id
          comm.stats[[j]]$r.id <- p.range.names[[j]]
          return(comm.stats[[j]])})

    rows <- lapply(comm.stat.rows, function(x)
          rbind(list(id=x$p.id, network=analysis.method,
                  release.range=x$r.id,
                  developers=x$vcount, num.comms=x$num.comms,
                  mean.conductance=x$mean.conductance,
                  sd.conductance=x$sd.conductance,
                  modularity=x$modularity,
                  mean.size=x$mean.size,
                  sd.size=x$sd.size,
                  mean.edges=x$mean.num.edges,
                  sd.edges=x$sd.num.edges)))

    for(i in idx){
      metrics.df <- rbind(metrics.df, rows[[i]])
    }
  }

  df <- merge(projects, metrics.df, all=TRUE)

  return(df)
}
