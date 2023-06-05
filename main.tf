provider "aws" {
  region = "ap-southeast-1"
}

############ Creating Security Group for EC2 & ELB ############

resource "aws_security_group" "web-server" {
  name        = "web-server"
  description = "Allow incoming HTTP Connections"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################## Creating 2 EC2 Instances ##################

resource "aws_instance" "web-server" {
  ami              = "ami-06ebb7936bfa62864"
  instance_type    = "t2.micro"
  count            = 2
  key_name         = "rga2"
  security_groups  = ["${aws_security_group.web-server.name}"]
  user_data        = <<-EOF
    #!/bin/bash
    sudo su
    yum update -y
    yum install httpd -y
    systemctl start httpd
    systemctl enable httpd
    echo "<html><h1> Welcome to Dinesh Kumar Page.This is a RGA Interview Assessment Simulation $(hostname -f)...</p> </h1></html>" >> /var/www/html/index.html
    EOF

  tags = {
    Name = "instance-${count.index}"
  }
}

###################### Default VPC and Subnets ######################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "subnet1" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "ap-southeast-1a"
}

data "aws_subnet" "subnet2" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "ap-southeast-1b"
}

#################### Creating Target Group ####################

resource "aws_lb_target_group" "target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "rga-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id
}

############# Creating Application Load Balancer #############

resource "aws_lb" "application-lb" {
  name            = "rga-alb"
  internal        = false
  ip_address_type = "ipv4"
  load_balancer_type = "application"
  security_groups = [aws_security_group.web-server.id]
  subnets = [
    data.aws_subnet.subnet1.id,
    data.aws_subnet.subnet2.id
  ]

  tags = {
    Name = "rga-alb"
  }
}

######################## Creating Listener ######################

resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.application-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target-group.arn
    type             = "forward"
  }
}

################ Attaching Target group to ALB ################

resource "aws_lb_target_group_attachment" "ec2_attach" {
  count             = length(aws_instance.web-server)
  target_group_arn  = aws_lb_target_group.target-group.arn
  target_id         = aws_instance.web-server[count.index].id
}

################ Creating AWS WAF ################

resource "aws_wafv2_web_acl" "web-acl" {
  name        = "rga-web-acl"
  description = "Web ACL to block web attacks"

  default_action {
    block {}
  }

  rule {
    name     = "block-sqli"
    priority = 1

    statement {
      sqli_match_statement {
        field_to_match {
          single_header {
            name = "referer"
          }
        }
      }
    }

    action {
      block {}
    }
  }

  rule {
    name     = "block-xss"
    priority = 2

    statement {
      xss_match_statement {
        field_to_match {
          single_header {
            name = "user-agent"
          }
        }
      }
    }

    action {
      block {}
    }
  }
}

############ Attaching AWS WAF to ALB ############

resource "aws_wafv2_web_acl_association" "web-acl-association" {
  resource_arn = aws_lb.application-lb.arn
  web_acl_arn  = aws_wafv2_web_acl.web-acl.arn
}