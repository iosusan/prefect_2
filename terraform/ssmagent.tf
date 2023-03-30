data "template_file" "ssmagent" {
  template = file("files/ssm-agent-install.sh")
}