data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "app" {
  name_prefix = "continuum-app-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name_prefix = "continuum-app-"
  role        = aws_iam_role.app.name
}

resource "aws_launch_template" "app" {
  name_prefix   = "continuum-app-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    mkdir -p /opt/continuum

    printf '%s' '${filebase64("${path.module}/../app/server.py")}' | base64 -d > /opt/continuum/server.py

    cat > /etc/systemd/system/continuum.service <<'SERVICE'
    [Unit]
    Description=Continuum application
    After=network-online.target
    Wants=network-online.target

    [Service]
    User=nobody
    ExecStart=/usr/bin/python3 /opt/continuum/server.py
    Restart=always
    RestartSec=3
    NoNewPrivileges=true

    [Install]
    WantedBy=multi-user.target
    SERVICE

    chmod 644 /opt/continuum/server.py
    systemctl daemon-reload
    systemctl enable --now continuum.service
  USERDATA
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "continuum-app" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "continuum-app-root" }
  }
}

resource "aws_lb" "app" {
  name               = "continuum-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for az in ["a", "b"] : aws_subnet.public[az].id]
}

resource "aws_lb_target_group" "app" {
  name        = "continuum-app-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_autoscaling_group" "app" {
  name_prefix               = "continuum-app-"
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 3
  health_check_type         = "ELB"
  health_check_grace_period = 180

  vpc_zone_identifier = [
    for az in ["a", "b"] : aws_subnet.app[az].id
  ]

  target_group_arns = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = {
      Name        = "continuum-app"
      Project     = "continuum"
      Environment = "lab"
      ManagedBy   = "terraform"
      Owner       = "personal-lab"
    }

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ssm
  ]
}
