resource "github_repository_webhook" "selfhosted_onpush" {
  events     = ["push"]
  repository = "selfhosted"

  configuration {
    url          = "https://web.dcotta.com/api/s-web-github-webhook/push"
    content_type = "json"
  }

}