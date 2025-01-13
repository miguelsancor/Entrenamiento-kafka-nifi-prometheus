provider "aws" {
  region = "us-west-2"
}

# AMI de Ubuntu para us-west-2
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Crear la instancia
resource "aws_instance" "tools_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.medium"

  key_name = "dockerinstance"

  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }

  # Script de inicialización
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Actualizar el sistema
              apt-get update -y && apt-get upgrade -y

              # Instalar Docker y dependencias
              apt-get install -y docker.io git curl

              # Instalar Docker Compose
              curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Crear directorio para las herramientas
              mkdir -p /home/ubuntu/tools
              cd /home/ubuntu/tools

              # Crear archivo docker-compose.yml para Kafka, NiFi, Grafana y Prometheus
              cat > docker-compose.yml <<-EOC
              version: '3.8'
              services:
                zookeeper:
                  image: confluentinc/cp-zookeeper:7.4.0
                  container_name: zookeeper
                  environment:
                    ZOOKEEPER_CLIENT_PORT: 2181
                    ZOOKEEPER_TICK_TIME: 2000
                  ports:
                    - "2181:2181"

                kafka:
                  image: confluentinc/cp-kafka:7.4.0
                  container_name: kafka
                  depends_on:
                    - zookeeper
                  environment:
                    KAFKA_BROKER_ID: 1
                    KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
                    KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
                    KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
                    KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
                  ports:
                    - "9092:9092"

                nifi:
                  image: apache/nifi:1.20.0
                  container_name: nifi
                  ports:
                    - "8080:8080"

                prometheus:
                  image: prom/prometheus:latest
                  container_name: prometheus
                  ports:
                    - "9090:9090"
                  volumes:
                    - ./prometheus.yml:/etc/prometheus/prometheus.yml

                grafana:
                  image: grafana/grafana:latest
                  container_name: grafana
                  environment:
                    - GF_SECURITY_ADMIN_USER=admin
                    - GF_SECURITY_ADMIN_PASSWORD=admin
                  ports:
                    - "3000:3000"
              EOC

              # Crear archivo prometheus.yml para la configuración básica
              cat > prometheus.yml <<-EOP
              global:
                scrape_interval: 15s

              scrape_configs:
                - job_name: 'prometheus'
                  static_configs:
                    - targets: ['localhost:9090']
                - job_name: 'kafka'
                  static_configs:
                    - targets: ['localhost:9092']
              EOP

              # Iniciar los contenedores con Docker Compose
              docker-compose up -d
              EOF

  tags = {
    Name = "ToolsInstance-New"
  }

  # Configuración de conexión SSH
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./dockerinstance.pem")
    host        = self.public_ip
  }

  # Validar que los contenedores se ejecuten correctamente
  provisioner "remote-exec" {
    inline = [
      "docker ps",
      "docker logs kafka || echo 'Kafka no inició correctamente'",
      "docker logs nifi || echo 'NiFi no inició correctamente'",
      "docker logs prometheus || echo 'Prometheus no inició correctamente'",
      "docker logs grafana || echo 'Grafana no inició correctamente'"
    ]
  }

  vpc_security_group_ids = [aws_security_group.tools_sg.id]
}

# Crear un grupo de seguridad
resource "aws_security_group" "tools_sg" {
  name        = "tools_security_group"
  description = "Allow inbound traffic for Kafka, NiFi, Prometheus, Grafana, and SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 9091
    to_port     = 9091
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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
