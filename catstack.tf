provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/Users/looneym/.aws/credentials"
  profile                 = "default"
}

resource "aws_vpc" "myapp" {
     cidr_block = "10.100.0.0/16"
}

resource "aws_subnet" "public_1a" {
    vpc_id = "${aws_vpc.myapp.id}"
    cidr_block = "10.100.0.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "us-east-1a"

    tags {
        Name = "Public 1A"
    }
}

resource "aws_subnet" "public_1b" {
    vpc_id = "${aws_vpc.myapp.id}"
    cidr_block = "10.100.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "us-east-1b"

    tags {
        Name = "Public 1B"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.myapp.id}"

    tags {
        Name = "myapp gw"
    }
}

resource "aws_security_group" "allow_ssh" {
  name = "allow_all"
  description = "Allow inbound SSH traffic from my IP"
  vpc_id = "${aws_vpc.myapp.id}"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["37.228.251.130/32"]
  }

  tags {
    Name = "Allow SSH"
  }
}

resource "aws_security_group" "web_server" {
  name = "web server"
  description = "Allow HTTP and HTTPS traffic in, browser access out."
  vpc_id = "${aws_vpc.myapp.id}"

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
      from_port = 1024
      to_port = 65535
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "myapp_mysql_rds" {
  name = "web server"
  description = "Allow access to MySQL RDS"
  vpc_id = "${aws_vpc.myapp.id}"

  ingress {
      from_port = 3306
      to_port = 3306
      protocol = "tcp"
      cidr_blocks = ["${aws_instance.web01.private_ip}","${aws_instance.web02.private_ip}"]
  }

  egress {
      from_port = 1024
      to_port = 65535
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web01" {
    ami = "ami-408c7f28"
    instance_type = "t1.micro"
    subnet_id = "${aws_subnet.public_1a.id}"
    vpc_security_group_ids = ["${aws_security_group.web_server.id}","${aws_security_group.allow_ssh.id}"]
    key_name = "myapp keypair"
    tags {
        Name = "web01"
    }
}

resource "aws_instance" "web02" {
    ami = "ami-408c7f28"
    instance_type = "t1.micro"
    subnet_id = "${aws_subnet.public_1b.id}"
    vpc_security_group_ids = ["${aws_security_group.web_server.id}","${aws_security_group.allow_ssh.id}"]
    key_name = "myapp keypair"
    tags {
        Name = "web02"
    }
}

resource "aws_elb" "web-elb" {
  name = "web-elb"
  availability_zones = ["us-east-1a", "us-east-1b"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }


  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }

  instances = ["${aws_instance.web01.id}","${aws_instance.web02.id}"]

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

  tags {
    Name = "Web ELB"
  }
}

resource "aws_db_subnet_group" "myapp-db" {
    name = "main"
    description = "Our main group of subnets"
    subnet_ids = ["${aws_subnet.public-1a.id}", "${aws_subnet.public-1b.id}"]
    tags {
        Name = "MyApp DB subnet group"
    }
}

resource "aws_db_instance" "web-rds-01" {
    identifier = "myappdb-rds"
    allocated_storage = 10
    engine = "mysql"
    engine_version = "5.6.17"
    instance_class = "db.t1.micro"
    name = "myappdb"
    username = "foo"
    password = "bar"
    vpc_security_group_ids = ["${aws_security_group.myapp_mysql_rds.id"]
    db_subnet_group_name = "${aws_db_subnet_group.myapp-db.id}"
    parameter_group_name = "default.mysql5.6"
}

