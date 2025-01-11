# Manual de Instalación: Prometheus, Kafka, Grafana y NiFi

## Prerrequisitos del Sistema
1. **Herramientas necesarias:**
   - **Windows:** Descargar Terraform y configurar las variables de entorno.
   - Cuenta de AWS: Crear un key pair `.pem` y nombrarlo como `dockerinstance.pem`.
   - Descargar Visual Studio Code u otro IDE de su preferencia.
   - Descargar MobaXterm.

2. **Instalaciones previas:**
   - Descargar e instalar Git.

---

## Instalación y Configuración

### 1. Inicialización de Terraform
Ejecutar los siguientes comandos:
```bash
terraform init
terraform plan
terraform apply
```

Validar la dirección pública generada.

---

### 2. Configuración de MobaXterm
- Asignar permisos y reiniciar sesión:
```bash
cd tools
sudo chmod u+w docker-compose.yml
sudo chmod 777 docker-compose.yml
sudo chown ubuntu:ubuntu docker-compose.yml
sudo usermod -aG docker ubuntu

sudo chmod u+w prometheus.yml
sudo chmod 777 prometheus.yml
sudo chown ubuntu:ubuntu prometheus.yml

sudo chown -R ubuntu:ubuntu /home/ubuntu/tools
```

---

### 3. Actualización de Archivos de Configuración
- Reemplace los contenidos de los archivos `prometheus.yml` y `docker-compose.yml` en la carpeta `tools` con los archivos disponibles en el repositorio Git.
- Verifique que tenga la dirección IP pública generada en AWS.

---

### 4. Iniciar Servicios
Ejecutar en la carpeta `tools`:
```bash
docker-compose up -d
```

Validar que los contenedores estén funcionando:
```bash
docker ps
docker ps -a
```

---

### 5. Configuración de Proxy Inverso
1. Instalar Nginx:
   ```bash
   sudo apt update
   sudo apt install nginx
   ```

2. Modificar configuración del proxy:
   ```bash
   sudo nano /etc/nginx/sites-available/nifi_proxy
   ```

   Contenido del archivo:
   ```nginx
   server {
       listen 9094;

       location /metrics/ {
           proxy_pass http://127.0.0.1:9091/metrics/;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

           add_header Content-Type "text/plain; version=0.0.4";
       }

       location = /favicon.ico {
           log_not_found off;
           access_log off;
       }
   }
   ```

3. Activar proxy inverso:
   ```bash
   sudo ln -s /etc/nginx/sites-available/nifi_proxy /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

4. Acceder a NiFi en el puerto 8080.

---

### 6. Configuración de Procesos en NiFi
- Crear procesos con los siguientes valores:
  ```json
  {"event":"test","value":123}
  ```
- Modificar el tiempo según sea necesario.
- Configurar `consumerKafka_2_0` con valores por defecto.
- Conectar flujos y establecer `relationships` a `terminate` para evitar advertencias.

---

### 7. Configuración de Prometheus
- Validar que el servicio esté arriba desde el proxy inverso en el puerto 9094.
- Asegurarse de que Prometheus esté activo (`UP`) en el puerto 9094.

---

### 8. Configuración de Grafana
1. Acceder al puerto 3000.
2. Configurar conexiones con Prometheus.
3. Crear un nuevo dashboard y graficar las siguientes variables:
   - `nifi_amount_flowfiles_transferred`: Total de FlowFiles transferidos.
   - `nifi_amount_bytes_sent`: Bytes enviados.
   - `nifi_amount_threads_active`: Hilos activos.

---

### 9. Validación de Datos Generados
Desde la línea de comandos:
```bash
docker exec -it kafka kafka-console-consumer --bootstrap-server <AWS_PUBLIC_IP>:9092 --topic metrics_topic --from-beginning
```

Reemplace `<AWS_PUBLIC_IP>` con la dirección IP pública generada.

---

¡Con esto, la instalación y configuración estarán completas!
