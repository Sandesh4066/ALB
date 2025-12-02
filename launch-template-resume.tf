resource "aws_launch_template" "resume_lt" {
  name = "resume-launch-template"
  
  image_id = "ami-0a0f1259dd1c90938"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.static_site_sg.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
yum update -y
dnf install nginx -y
systemctl enable nginx
systemctl start nginx

echo "<h1>Sandesh Resume Website</h1>" > /usr/share/nginx/html/index.html
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Resume-Server"
    }
  }
}
resource "aws_lb_target_group" "resume_tg" {
  name     = "resume-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"
    port = "80"
  }
}
resource "aws_lb" "resume_alb" {
  name               = "resume-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.static_site_sg.id]
  subnets            = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.resume_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.resume_tg.arn
  }
}
resource "aws_autoscaling_group" "resume_asg" {
  name                = "resume-asg"
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  health_check_type   = "EC2"
  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  launch_template {
    id      = aws_launch_template.resume_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.resume_tg.arn]
}
output "alb_dns" {
  value = aws_lb.resume_alb.dns_name
}
