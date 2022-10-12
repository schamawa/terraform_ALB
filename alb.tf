provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "test_vpc" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "vpc"
  }
}

##########Subnet ap-south-1a######################################

resource "aws_subnet" "test_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.10.3.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "subnet"
  }
}

##########Subnet ap-south-1b######################################

resource "aws_subnet" "test_subnet1" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.10.4.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "subnet2"
  }
}

################ IGW ################################################

resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "test_IGW"
  }
}

##################### Route_Table ######################################

resource "aws_route_table" "test_rt" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # All resources in public subnet are accessible from all internet.
    gateway_id = aws_internet_gateway.test_igw.id
  }

  tags = {
    Name = "Public-route"
  }
}

resource "aws_route_table_association" "test_rta" {
  route_table_id = aws_route_table.test_rt.id
  subnet_id      = aws_subnet.test_subnet.id
}


resource "aws_route_table" "test_rt1" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # All resources in public subnet are accessible from all internet.
    gateway_id = aws_internet_gateway.test_igw.id
  }

  tags = {
    Name = "Public-route1"
  }
}

resource "aws_route_table_association" "test_rta1" {
  route_table_id = aws_route_table.test_rt1.id
  subnet_id      = aws_subnet.test_subnet1.id
}


################ Security_Group ###############################################

resource "aws_security_group" "test_sg" {
  name   = "test_sg"
  vpc_id = aws_vpc.test_vpc.id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test_sg"
  }

}

##############################EC2 Instance ###############################################

resource "aws_instance" "test_ec2" {
  ami           = "ami-076e3a557efe1aa9c" # ap-south1
  subnet_id     = aws_subnet.test_subnet.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.test_sg.id]

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<h1>Hello World from $(hostname -f) in AZ $EC2_AVAIL_ZONE </h1>" > /var/www/html/index.html
EOF


  tags = {
    Name = "test-ec2"
  }


}


resource "aws_instance" "test1_ec2" {
  ami           = "ami-076e3a557efe1aa9c" # ap-south1
  subnet_id     = aws_subnet.test_subnet1.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.test_sg.id]

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<h1>Hello World from $(hostname -f) in AZ $EC2_AVAIL_ZONE </h1>" > /var/www/html/index.html
EOF


  tags = {
    Name = "test1-ec2"
  }


}

####################Application Load Balancer #########################

resource "aws_lb_target_group" "test-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "test-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.test_vpc.id
}


resource "aws_lb_target_group_attachment" "test-alb-target-group-attachment1" {
  target_group_arn = "${aws_lb_target_group.test-target-group.arn}"
  target_id        = aws_instance.test_ec2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "test-alb-target-group-attachment2" {
  target_group_arn = "${aws_lb_target_group.test-target-group.arn}"
  target_id        = aws_instance.test1_ec2.id
  port             = 80
}


resource "aws_lb" "test-aws-alb" {
  name     = "test-test-alb"
  internal = false

  security_groups = [aws_security_group.test_sg.id]

  subnets = [aws_subnet.test_subnet.id, aws_subnet.test_subnet1.id]

  tags = {
    Name = "test-alb"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}


resource "aws_lb_listener" "test-alb-listner" {
  load_balancer_arn = "${aws_lb.test-aws-alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.test-target-group.arn}"
  }
}


