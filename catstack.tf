provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/Users/looneym/.aws/credentials"
  profile                 = "default"
}

resource "aws_vpc" "myapp" {
     cidr_block = "10.100.0.0/16"   
}

resource "aws_main_route_table_association" "a" {
  vpc_id = "${aws_vpc.myapp.id}"
  route_table_id = "${aws_route_table.r.id}"
}

resource "aws_security_group" "allow_ssh" {
  name = "allow_all"
  description = "Allow inbound SSH traffic from my IP"
  vpc_id = "${aws_vpc.myapp.id}"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
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


resource "aws_instance" "web01" {
    ami = "ami-408c7f28"
    instance_type = "t1.micro"
    subnet_id = "${aws_subnet.public_1a.id}"
    vpc_security_group_ids = ["${aws_security_group.web_server.id}","${aws_security_group.allow_ssh.id}"]
    key_name = "sobotka"
    tags {
        Name = "web01"
    }
}

resource "aws_security_group" "mydb1" {  
  name = "mydb1"

  description = "RDS postgres servers (terraform-managed)"
  vpc_id = "${aws_vpc.myapp.id}"

  # Only postgres in
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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


resource "aws_db_subnet_group" "myapp-db" {
    name = "main"
    description = "Our main group of subnets"
    subnet_ids = ["${aws_subnet.public_1a.id}", "${aws_subnet.public_1b.id}"]
    tags {
        Name = "MyApp DB subnet group"
    }
}


resource "aws_db_instance" "mydb1" {  
  allocated_storage        = 10 # gigabytes
  backup_retention_period  = 7   # in days
  db_subnet_group_name     = "${aws_db_subnet_group.myapp-db.id}"
  engine                   = "postgres"
  engine_version           = "9.5.4"
  identifier               = "mydb1"
  instance_class           = "db.r3.large"
  multi_az                 = false
  name                     = "mydb1"
  # parameter_group_name     = "mydbparamgroup1" # if you have tuned it
  password                 = "password"
  port                     = 5432
  publicly_accessible      = false
  storage_encrypted        = true # you should always do this
  storage_type             = "gp2"
  username                 = "mydb1"
  skip_final_snapshot      = true
  vpc_security_group_ids   = ["${aws_security_group.mydb1.id}"]
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


resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.myapp.id}"

    tags {
        Name = "myapp gw"
    }
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.myapp.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

}



