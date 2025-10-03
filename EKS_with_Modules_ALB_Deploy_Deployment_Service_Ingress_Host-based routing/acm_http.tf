# ---------------- ACM Certificate ----------------
#resource "aws_acm_certificate" "app_cert" {
#  domain_name       = "krish.kozow.com" # replace with your domain
#  validation_method = "DNS"
#}

#resource "aws_acm_certificate_validation" "app_cert_validation" {
#  certificate_arn = aws_acm_certificate.app_cert.arn
#}



#################################
# ACM Certificates for Both Domains
#################################

resource "aws_acm_certificate" "multi_cert" {
  domain_name       = "krish.kozow.com"
  subject_alternative_names = [
    "app1.krish.kozow.com",
    "app2.krish.kozow.com"
  ]
  validation_method = "DNS"
}

# DNS Validation Records (for each domain)
#resource "aws_route53_record" "cert_validation_app" {
#  name    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_name
#  type    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_type
#  zone_id = "ZXXXXXXXXXXXX" # Replace with your Route53 Hosted Zone ID
#  records = [tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_value]
#  ttl     = 60
#}

#resource "aws_route53_record" "cert_validation_api" {
#  name    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_name
#  type    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_type
#  zone_id = "ZXXXXXXXXXXXX"
#  records = [tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_value]
#  ttl     = 60
#}

resource "aws_acm_certificate_validation" "multi_cert_validation" {
  certificate_arn         = aws_acm_certificate.multi_cert.arn
#  validation_record_fqdns = [
#    aws_route53_record.cert_validation_app.fqdn,
#    aws_route53_record.cert_validation_api.fqdn
#  ]
}


# ---------------- Listeners ----------------
#resource "aws_lb_listener" "https" {
#  load_balancer_arn = aws_lb.app_lb.arn
#  port              = "443"
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = aws_acm_certificate_validation.app_cert_validation.certificate_arn

#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_tg_root.arn
#  }
#}

# Path-based routing rules
#resource "aws_lb_listener_rule" "root_rule" {
#  listener_arn = aws_lb_listener.https.arn
#  priority     = 10

#  action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_tg_root.arn
#  }

#  condition {
#    path_pattern {
#      values = ["/"]
#    }
#  }
#}

#resource "aws_lb_listener_rule" "payment_rule" {
#  listener_arn = aws_lb_listener.https.arn
#  priority     = 20

#  action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_tg_payment.arn
#  }

#  condition {
#    path_pattern {
#      values = ["/payment*"]
#    }
#  }
#}

# HTTP → HTTPS Redirect
#resource "aws_lb_listener" "http_redirect" {
#  load_balancer_arn = aws_lb.app_lb.arn
#  port              = "80"
#  protocol          = "HTTP"

#  default_action {
#    type = "redirect"
#    redirect {
#      port        = "443"
#      protocol    = "HTTPS"
#      status_code = "HTTP_301"
#    }
#  }
#}
