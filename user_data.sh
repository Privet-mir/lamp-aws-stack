#!/bin/bash

# This script installs and configures Apache, PHP, and connects to RDS MySQL

# Log all output
exec > >(tee /var/log/lamp-installation.log) 2>&1

echo "Starting LAMP stack installation at $(date)"
echo "Database Endpoint: ${db_endpoint}"
echo "Database Name: ${db_name}"
echo "Database Username: ${db_username}"

# Update system
yum update -y

# Install Apache (but don't start yet)
yum install -y httpd

# Install PHP 8.3 and required extensions (via Remi repository)
yum install -y yum-utils
amazon-linux-extras install epel -y || true
yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm

# Install PHP 8.3 with Apache module and required extensions
yum install -y php83 php83-php-cli php83-php-common php83-php-fpm php83-php-mysqlnd php83-php-json php83-php-xml php83-php-mbstring php83-php-gd php83-php-curl

# Install Apache PHP module for PHP 8.3
yum install -y php83-php

# Create symlinks for php commands to point to php83
ln -sf /usr/bin/php83 /usr/bin/php
ln -sf /usr/bin/php83 /usr/bin/php-cli

# Verify PHP 8.3 module exists
if [ -f "/usr/lib64/httpd/modules/libphp83.so" ]; then
    echo "PHP 8.3 module found: /usr/lib64/httpd/modules/libphp83.so"
    
    # Configure Apache to use PHP 8.3 module
    cat > /etc/httpd/conf.modules.d/10-php83.conf << 'EOF'
LoadModule php_module /usr/lib64/httpd/modules/libphp83.so
AddType application/x-httpd-php .php
DirectoryIndex index.php index.html
EOF
else
    echo "ERROR: PHP 8.3 module not found at /usr/lib64/httpd/modules/libphp83.so"
    echo "Available PHP modules:"
    ls -la /usr/lib64/httpd/modules/libphp* 2>/dev/null || echo "No PHP modules found"
    exit 1
fi

# Verify PHP 8.3 installation
echo "Verifying PHP 8.3 installation..."
php -v

# Stop any existing Apache processes and start fresh
systemctl stop httpd || true
systemctl daemon-reload

# Test Apache configuration before starting
echo "Testing Apache configuration..."
httpd -t
if [ $? -ne 0 ]; then
    echo "ERROR: Apache configuration test failed"
    exit 1
fi

# Start and enable Apache (now that PHP is configured)
systemctl start httpd
systemctl enable httpd

# Verify Apache installation and status
echo "Verifying Apache installation..."
systemctl status httpd
httpd -v
php -v

# Install MySQL client
yum install -y mysql

# Install AWS CLI, jq, and CloudWatch agent for monitoring
yum install -y awscli jq
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Test IAM role access to RDS
echo "Testing IAM role access to RDS..."
aws sts get-caller-identity
aws rds describe-db-instances --region ${aws_region} --db-instance-identifier ${db_instance_identifier} || echo "RDS instance not found or not accessible"

# Wait for VPC endpoints and RDS to be available
echo "Waiting for VPC endpoints and RDS to be available..."
sleep 60

# Test SSM connectivity
echo "Testing SSM connectivity..."
for i in {1..5}; do
  if aws ssm describe-instance-information --region ${aws_region} >/dev/null 2>&1; then
    echo "SSM connectivity successful"
    break
  else
    echo "SSM connectivity attempt $i failed, retrying in 30 seconds..."
    sleep 30
  fi
done

# Create web directory
mkdir -p /var/www/html/lamp

# Ensure proper permissions for web directory
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Create a simple HTML homepage
echo "Creating index.html..."
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP Stack on AWS</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .status {
            background-color: #e8f5e8;
            border: 1px solid #4caf50;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .info {
            background-color: #e3f2fd;
            border: 1px solid #2196f3;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .links {
            text-align: center;
            margin-top: 30px;
        }
        .links a {
            display: inline-block;
            margin: 10px;
            padding: 10px 20px;
            background-color: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 5px;
        }
        .links a:hover {
            background-color: #0056b3;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 LAMP Stack on AWS</h1>
        
        <div class="status">
            <h3>✅ System Status</h3>
            <p><strong>Apache:</strong> Running</p>
            <p><strong>PHP:</strong> Installed and Configured</p>
            <p><strong>MySQL:</strong> Connected to RDS</p>
            <p><strong>Load Balancer:</strong> Active</p>
        </div>
        
        <div class="info">
            <h3>📋 Stack Information</h3>
            <p><strong>Infrastructure:</strong> Terraform</p>
            <p><strong>Cloud Provider:</strong> Amazon Web Services (AWS)</p>
            <p><strong>Operating System:</strong> Amazon Linux 2</p>
            <p><strong>Web Server:</strong> Apache HTTP Server</p>
            <p><strong>Database:</strong> MySQL (RDS)</p>
            <p><strong>Scripting Language:</strong> PHP</p>
        </div>
        
        <div class="links">
            <a href="/sample_app.php">Fugro Application</a>
        </div>
    </div>
</body>
</html>
EOF

# Fetch database credentials from AWS Secrets Manager
echo "Fetching database credentials from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${secrets_manager_secret_name} --region ${aws_region} --query SecretString --output text)
if [ -z "$SECRET_JSON" ]; then
    echo "Failed to retrieve database credentials from Secrets Manager"
    exit 1
fi

# Parse the JSON to extract individual values
DB_HOST=$(echo $SECRET_JSON | jq -r '.host')
DB_NAME=$(echo $SECRET_JSON | jq -r '.dbname')
DB_USERNAME=$(echo $SECRET_JSON | jq -r '.username')
DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.password')
DB_PORT=$(echo $SECRET_JSON | jq -r '.port')
if [ -z "$DB_PORT" ] || [ "$DB_PORT" = "null" ]; then DB_PORT=3306; fi

echo "Database credentials retrieved successfully"

# Test database connection
echo "Testing database connection..."
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" --password="$DB_PASSWORD" -e "SELECT 1;" "$DB_NAME" || echo "Database connection failed"

# Create sample application
echo "Creating sample_app.php..."
cat > /var/www/html/sample_app.php << 'EOF'
<?php
// Database configuration (credentials fetched from Secrets Manager during instance initialization)
$host = '__DB_HOST__';
$dbname = '__DB_NAME__';
$username = '__DB_USERNAME__';
$password = '__DB_PASSWORD__';
$port = (int) '__DB_PORT__';

echo "<h1>Fugro LAMP Application</h1>";

// Connect using mysqli (compatible with PHP 8.3)
$mysqli = new mysqli($host, $username, $password, $dbname, $port);
if ($mysqli->connect_errno) {
    http_response_code(500);
    echo "Failed to connect to MySQL: " . htmlspecialchars($mysqli->connect_error);
    exit;
}

// Create messages table if it doesn't exist
$mysqli->query("CREATE TABLE IF NOT EXISTS messages (id INT AUTO_INCREMENT PRIMARY KEY, message TEXT NOT NULL)");

// Ensure the Fugro message exists
$msg = 'tech assessment - fugro';
$stmt = $mysqli->prepare("SELECT COUNT(*) FROM messages WHERE message = ?");
$stmt->bind_param('s', $msg);
$stmt->execute();
$stmt->bind_result($count);
$stmt->fetch();
$stmt->close();
if ((int)$count === 0) {
    $stmt = $mysqli->prepare("INSERT INTO messages (message) VALUES (?)");
    $stmt->bind_param('s', $msg);
    $stmt->execute();
    $stmt->close();
}

// Display the Fugro message
$stmt = $mysqli->prepare("SELECT message FROM messages WHERE message = ? LIMIT 1");
$stmt->bind_param('s', $msg);
$stmt->execute();
$stmt->bind_result($message);
$stmt->fetch();
$stmt->close();

if (!empty($message)) {
    echo "<h2>Message from Database: " . htmlspecialchars($message) . "</h2>";
}

$mysqli->close();
?>
EOF

# Replace placeholders in PHP with actual credentials
PHP_FILE="/var/www/html/sample_app.php"
ESC_HOST=$(printf '%s' "$DB_HOST" | sed -e 's/[\&/|]/\\&/g')
ESC_NAME=$(printf '%s' "$DB_NAME" | sed -e 's/[\&/|]/\\&/g')
ESC_USER=$(printf '%s' "$DB_USERNAME" | sed -e 's/[\&/|]/\\&/g')
ESC_PASS=$(printf '%s' "$DB_PASSWORD" | sed -e 's/[\&/|]/\\&/g')
ESC_PORT=$(printf '%s' "$DB_PORT" | sed -e 's/[\&/|]/\\&/g')
sed -i "s|__DB_HOST__|$ESC_HOST|g" "$PHP_FILE"
sed -i "s|__DB_NAME__|$ESC_NAME|g" "$PHP_FILE"
sed -i "s|__DB_USERNAME__|$ESC_USER|g" "$PHP_FILE"
sed -i "s|__DB_PASSWORD__|$ESC_PASS|g" "$PHP_FILE"
sed -i "s|__DB_PORT__|$ESC_PORT|g" "$PHP_FILE"

# Set  permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart Apache to ensure all configurations are loaded
systemctl restart httpd

# Create a simple health check endpoint
cat > /var/www/html/health.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode([
    'status' => 'healthy',
    'timestamp' => date('Y-m-d H:i:s'),
    'server' => $_SERVER['SERVER_SOFTWARE'],
    'php_version' => phpversion()
]);
?>
EOF

# Restart of Apache to ensure all configurations are loaded
echo "Final Apache restart..."
systemctl restart httpd
systemctl status httpd

# Restart SSM agent to ensure it connects to VPC endpoints
echo "Restarting SSM agent..."
systemctl restart amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Check SSM agent status
sleep 10
systemctl status amazon-ssm-agent

# Configure CloudWatch agent
echo "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": true
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time",
                    "read_bytes",
                    "write_bytes",
                    "reads",
                    "writes"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "/aws/ec2/${project_name}/apache/access",
                        "log_stream_name": "{instance_id}-access"
                    },
                    {
                        "file_path": "/var/log/httpd/error_log",
                        "log_group_name": "/aws/ec2/${project_name}/apache/error",
                        "log_stream_name": "{instance_id}-error"
                    },
                    {
                        "file_path": "/var/log/lamp-installation.log",
                        "log_group_name": "/aws/ec2/${project_name}/application",
                        "log_stream_name": "{instance_id}-installation"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Verify files were created
echo "Verifying created files..."
ls -la /var/www/html/
echo "File verification complete"

# Logs
echo "LAMP stack installation completed at $(date)" >> /var/log/lamp-installation.log
echo "Apache status:" >> /var/log/lamp-installation.log
systemctl status httpd >> /var/log/lamp-installation.log 2>&1
echo "SSM agent status:" >> /var/log/lamp-installation.log
systemctl status amazon-ssm-agent >> /var/log/lamp-installation.log 2>&1
echo "CloudWatch agent status:" >> /var/log/lamp-installation.log
systemctl status amazon-cloudwatch-agent >> /var/log/lamp-installation.log 2>&1
echo "Files in /var/www/html:" >> /var/log/lamp-installation.log
ls -la /var/www/html/ >> /var/log/lamp-installation.log 2>&1