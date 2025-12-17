# =============================================================================
# Jenkins EC2 Server Configuration
# To deploy only Jenkins: terraform apply -target=aws_instance.jenkins
# =============================================================================

# Data source for Amazon Linux 2 AMI (Free Tier eligible, smaller base size)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Jenkins Server
resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins web UI on port 8080
  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

# IAM Role for Jenkins EC2
resource "aws_iam_role" "jenkins" {
  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "jenkins-ec2-role"
  }
}

# IAM policies for Jenkins to interact with ECR and EKS
resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.jenkins.name
}

# Custom policy for EKS access
resource "aws_iam_policy" "jenkins_eks_access" {
  name        = "jenkins-eks-access-policy"
  description = "Allow Jenkins to describe EKS clusters and update kubeconfig"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_eks_access" {
  policy_arn = aws_iam_policy.jenkins_eks_access.arn
  role       = aws_iam_role.jenkins.name
}

# Custom policy for S3 access to Terraform state
resource "aws_iam_policy" "jenkins_s3_access" {
  name        = "jenkins-s3-terraform-state-policy"
  description = "Allow Jenkins to read Terraform state from S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::assignment-bucket-equalexperts",
          "arn:aws:s3:::assignment-bucket-equalexperts/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_s3_access" {
  policy_arn = aws_iam_policy.jenkins_s3_access.arn
  role       = aws_iam_role.jenkins.name
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "jenkins" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins.name
}

# Jenkins EC2 Instance (t2.medium - Better performance for Docker builds)
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.medium"
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 10
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -ex

              # Update system
              yum update -y

              # Install Java 17 (required for Jenkins)
              yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel

              # Add Jenkins repo
              wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

              # Install Jenkins
              yum install -y jenkins

              # Start and enable Jenkins
              systemctl enable jenkins
              systemctl start jenkins

              # Install Git
              yum install -y git

              # Install Python 3 and pip
              yum install -y python3 python3-pip

              # Install Docker
              yum install -y docker
              systemctl enable docker
              systemctl start docker
              usermod -aG docker jenkins
              usermod -aG docker ec2-user

              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/

              # Install AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              yum install -y unzip
              unzip awscliv2.zip
              ./aws/install

              # Install Terraform
              yum install -y yum-utils
              yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
              yum install -y terraform

              # Restart Jenkins to pick up Docker group
              systemctl restart jenkins

              echo "Jenkins installation completed!"
              EOF

  tags = {
    Name = "jenkins-server"
  }
}
