package main

//goland:noinspection GoSnakeCaseUsage
import (
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_nomad "github.com/cottand/selfhosted/dev-go/services/s-rpc-nomad-api"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/services/s-rpc-portfolio-stats"
	s_rpc_vault "github.com/cottand/selfhosted/dev-go/services/s-rpc-vault"
	s_web_github_webhook "github.com/cottand/selfhosted/dev-go/services/s-web-github-webhook"
	s_web_portfolio "github.com/cottand/selfhosted/dev-go/services/s-web-portfolio"
)

func main() {
	mono.Register(s_web_github_webhook.InitService)
	mono.Register(s_rpc_nomad.InitService)
	mono.Register(s_rpc_portfolio_stats.InitService)
	mono.Register(s_web_portfolio.InitService)
	mono.Register(s_rpc_vault.InitService)

	mono.RunRegistered()
}
