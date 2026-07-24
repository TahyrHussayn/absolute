resource "aws_launch_template" "beam_lt" {
  name_prefix   = "absolute-beam-lt-${var.environment}"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    security_groups             = [aws_security_group.beam_cluster_sg.id]
    associate_public_ip_address = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.tftpl", {
    repo_url    = var.repo_url
    environment = var.environment
    aws_region  = var.aws_region
    image_tag   = var.image_tag
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "absolute-beam-node"
      Environment = var.environment
    }
  }
}

resource "aws_autoscaling_group" "beam_asg" {
  name                = "absolute-beam-asg-${var.environment}"
  vpc_zone_identifier = data.aws_subnets.default.ids
  min_size            = var.node_count
  max_size            = var.node_count * 2
  desired_capacity    = var.node_count

  health_check_type         = "ELB"
  health_check_grace_period = 300

  target_group_arns = [aws_lb_target_group.absolute_tg.arn]

  launch_template {
    id      = aws_launch_template.beam_lt.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "absolute-beam-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}
