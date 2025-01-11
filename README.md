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
1. **Crear los siguientes procesadores:**
   - **GenerateFlowFile:** Configurar con los siguientes valores:
     - `Custom Text`: `{ "event": "test", "value": 123 }`
     - `Run Schedule`: `5 sec`
   
   - **PublishKafka_2_0:**
     - `bootstrap.servers`: `<IP:PORT>` (Ejemplo: `127.0.0.1:9092`)
     - `Topic Name`: `metrics_topic`

   - **ConsumeKafka_2_0:**
     - `bootstrap.servers`: `<IP:PORT>`
     - `Topic Name`: `metrics_topic`
     - `Group ID`: `nifi-group`

   - **LogAttribute:** Dejar configuración por defecto.

2. **Conectar los flujos:**
   - Conectar `GenerateFlowFile` con `PublishKafka_2_0`.
   - Conectar `PublishKafka_2_0` con `ConsumeKafka_2_0`.
   - Conectar `ConsumeKafka_2_0` con `LogAttribute`.

3. **Configurar relaciones:**
   - En todos los procesadores, establecer `success` y `failure` hacia los siguientes procesadores correspondientes.
   - Verificar que todos los procesos estén en estado `Running`.

4. **Iniciar los procesadores:**
   - Seleccionar todos los procesadores y hacer clic en `Start`.

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
4. Asegurar la correcta visualización de métricas y realizar ajustes en los paneles según las necesidades.

---

### 9. Validación de Datos Generados
Desde la línea de comandos:
```bash
docker exec -it kafka kafka-console-consumer --bootstrap-server <AWS_PUBLIC_IP>:9092 --topic metrics_topic --from-beginning
```

Reemplace `<AWS_PUBLIC_IP>` con la dirección IP pública generada.

### 10. Tareas Adicionales de Validación
1. Desde el entorno gráfico de NiFi, valide la correcta transferencia de `FlowFiles`.
2. Verifique las conexiones en `Kafka` y asegúrese de que los mensajes se envíen correctamente al tópico correspondiente.
3. Monitoree los gráficos en Grafana para confirmar la sincronización en tiempo real entre las métricas de Prometheus y los datos de NiFi.

---

¡Con esto, la instalación y configuración estarán completas!
