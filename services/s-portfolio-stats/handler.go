package main

import s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"

type ProtoHandler struct {
}

var _ s_portfolio_stats.Visit
