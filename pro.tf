provider "aws" {
  region = "ap-south-1"
  profile = "akshat"
}

resource "aws_key_pair" "deployer" {
  key_name   = "key123"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAoyWE3f7jPfp7tcl02bTpIbQV8ZtjEgCiP+D6nBQ9Qi/mF786MxZvVoIy4G5wlP+R31v+T54w51x/ZQdSbcdRhjxsqKAt1TXFz24FibuMzSOPa8poXPNDRvWDiYl62PV6iwu/fLE7Z895cpm4qFwRhBiKaSrqhr65zYhahgs5pBOzjnroHYz1zPKKX+Wtrvb9wZn3eMKORsPJOjKe17NBEbNr6thnIJ2MK8CvkLbpTAfgQi1iF15Hy/LANx+PpOI6F2C+gjwigCWfElbQMIC3pOQO8sMQ9UFqBD3z9M5o9yVpcXNxrBLTcMfseIKCJG+ZVKGGybgjwasExcDcLyPB4w== rsa-key-20200613"
}

resource "aws_security_group" "security_gp" {
  name        = "security-1"
  description = "Port for webserver and ssh"
  vpc_id      = "vpc-70746818"


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   tags = {
    Name = "task1_securitygroup"
  }
}

resource "aws_ebs_volume" "ebsvol" {
  availability_zone = "ap-south-1a"
  size  = 1
  tags = {
    Name = "volume1"
  }
}

resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdf"
  volume_id   = "${aws_ebs_volume.ebsvol.id}"
  instance_id = "${aws_instance.webserver.id}"
  force_detach = true
}

resource "aws_instance" "webserver" {
 ami            ="ami-0447a12f28fddb066"
 instance_type  = "t2.micro"
 availability_zone = "ap-south-1a"
 key_name       = "key123"
 security_groups = ["security-1"]
 user_data = <<-EOF
         #!/bin/bash
         sudo yum install httpd -y
	 sudo systemctl start httpd
         sudo systemctl enable httpd
         sudo yum install git -y
         sudo mkfs.ext4 /dev/xvdf1
         sudo mount /dev/xvdf1 /var/www/html/
	 sudo rm -rf /var/www/html/*
         sudo git clone https://github.com/akshatkumar21/cloud-web-server.git /var/www/html/

 EOF
 tags = {
    Name = "WebServer"
 }
}

output "myos_ip" {
  value = aws_instance.webserver.public_ip
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.webserver.public_ip} > publicip.txt"
  	}
}

output  "myaz" {
	value = aws_instance.webserver.availability_zone
}

output "instanceID"{
	value=aws_instance.webserver.id
}

output "ebsvolumeID"{
	value=aws_ebs_volume.ebsvol.id
}


resource "aws_s3_bucket" "my-test-s3-akshat-bucket" {   
	bucket = "my-test-s3-akshat-bucket"
	acl="public-read"
        force_destroy=true   
	tags = {     
	      Name = "My Image Bucket "   
		} 
} 

resource "aws_s3_bucket_public_access_block" "aws_public_access" {
  bucket = "${aws_s3_bucket.my-test-s3-akshat-bucket.id}"

 block_public_acls   = false
  block_public_policy = false
}

resource "aws_cloudfront_distribution" "s3_distribution" {   
	origin {     
	domain_name = "${aws_s3_bucket.my-test-s3-akshat-bucket.bucket_regional_domain_name}"     
        origin_id   = "${aws_s3_bucket.my-test-s3-akshat-bucket.id}"  
               } 

  	enabled             = true   
  	is_ipv6_enabled     = true   
  	comment             = "S3 bucket"  

    default_cache_behavior {     
	allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]     
	cached_methods   = ["GET", "HEAD"]     
	target_origin_id = "${aws_s3_bucket.my-test-s3-akshat-bucket.id}" 

    forwarded_values {       
		query_string = false  
          cookies {         
		forward = "none"       
            }     
        }  
 
	viewer_protocol_policy = "allow-all"     
	min_ttl                = 0     
	default_ttl            = 3600     
	max_ttl                = 86400   
 }  

 # Cache behavior with precedence 0   
	ordered_cache_behavior {     
		path_pattern     = "/content/immutable/*"     
		allowed_methods  = ["GET", "HEAD", "OPTIONS"]     
		cached_methods   = ["GET", "HEAD", "OPTIONS"]     
		target_origin_id = "${aws_s3_bucket.my-test-s3-akshat-bucket.id}"  

   forwarded_values {       
	query_string = false  
        cookies {         
		forward = "none"       
	   }     
         }  
	
	min_ttl                = 0     
	default_ttl            = 86400     
	max_ttl                = 31536000 
	compress               = true     
	viewer_protocol_policy = "redirect-to-https"   
}   
 	restrictions {     
	geo_restriction {       
		restriction_type = "whitelist"       
		locations        = ["IN"]     
		}   
	}  

	tags = {     
		Environment = "production"   
		}  
  	viewer_certificate {     
		cloudfront_default_certificate = true   
			}  
  	depends_on = [ aws_s3_bucket.my-test-s3-akshat-bucket ] 
 } 


resource "aws_ebs_snapshot" "task1_snapshot" {
  volume_id = "${aws_ebs_volume.ebsvol.id}"


  tags = {
    Name = "EBS_Snapshot"
  }
} 