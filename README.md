# Microblog VPC Deployment on Google Cloud Platform

## PURPOSE
The purpose of this workload is to create a robust, secure cloud infrastructure for deploying a Flask microblog application using infrastructure-as-code and CI/CD principles on Google Cloud Platform. This project demonstrates how to properly separate concerns across a network architecture by:

1. Placing web-facing components in public subnets
2. Securing application components in private subnets
3. Implementing a continuous integration and deployment pipeline
4. Setting up monitoring for the deployed application

By completing this project, I've gained hands-on experience with deploying applications in a production-ready environment using Google Cloud services and Terraform for infrastructure provisioning.

## STEPS

### 1. Infrastructure Provisioning with Terraform
I used Terraform to provision all the required infrastructure components in Google Cloud Platform. This approach ensures that our infrastructure is reproducible, maintainable, and can be version-controlled.

Key components created:
- Custom VPC Network with public and private subnets
- Cloud Router and Cloud NAT for private subnet connectivity
- Firewall rules to control network traffic
- Compute Engine instances for different application components

**Why important:** Infrastructure-as-code allows for consistent deployments, reduces human error, and enables version control for infrastructure changes.

### 2. Setting Up the Jenkins Server
I created an e2-medium Compute Engine instance in the public subnet to host Jenkins, our CI/CD server. This required:
- Installing Jenkins and necessary plugins
- Configuring Jenkins with SSH keys for deployment
- Setting up the OWASP Dependency Check plugin

**Why important:** A dedicated CI/CD server automates building, testing and deployment processes, ensuring consistent and reliable deployments.

### 3. Configuring the Web Server
I set up an e2-small Compute Engine instance in the public subnet to serve as our web server with:
- Nginx installation and configuration
- Reverse proxy setup to forward requests to the application server
- SSH key configuration for secure communication with the app server

**Why important:** The web server acts as a gateway, handling external web traffic and forwarding only legitimate requests to our application server in the private subnet, adding a layer of security.

### 4. Setting Up the Application Server
I provisioned an e2-small Compute Engine instance in the private subnet where our Flask application runs:
- Created start_app.sh script to handle application deployment
- Configured necessary dependencies for the Flask application
- Set up environment variables and database connection

**Why important:** Keeping the application server in a private subnet protects it from direct internet access, reducing the attack surface.

### 5. Creating Deployment Scripts
I created two key scripts to automate the deployment process:
- `start_app.sh`: Runs on the application server to set up and start the Flask application
- `setup.sh`: Runs on the web server to initiate deployment on the application server

**Why important:** These scripts automate the deployment process, making it consistent and repeatable while reducing human error.

### 6. Creating the CI/CD Pipeline with Jenkins
I implemented a Jenkinsfile that defines a complete pipeline:
- Build stage: Sets up the Python environment and installs dependencies
- Test stage: Runs pytest to validate application functionality
- Security scan: Uses OWASP Dependency Check to identify vulnerabilities
- Deploy stage: Executes the deployment scripts on target servers

**Why important:** The pipeline ensures that code changes are automatically built, tested, scanned for vulnerabilities, and deployed, maintaining quality and security throughout the development lifecycle.

### 7. Setting Up Monitoring
I deployed Prometheus and Grafana on a separate e2-small instance to monitor our application:
- Configured Prometheus to collect metrics from the application server
- Set up Grafana dashboards to visualize performance and health metrics
- Enabled anonymous access to Grafana API for easier integration

**Why important:** Monitoring provides visibility into the application's performance and health, enabling proactive identification and resolution of issues.

## SYSTEM DESIGN DIAGRAM

![System Architecture Diagram](GCP-Diagram.jpg)

The diagram illustrates the network architecture and components of our deployment:
- VPC Network with public and private subnets
- Jenkins, web server, and monitoring server in the public subnet
- Application server with SQLite database in the private subnet
- Cloud NAT for private subnet internet access
- Network connections and firewall configurations

## ISSUES/TROUBLESHOOTING

During the implementation of this project, I encountered and resolved several challenges:

1. **Circular Dependency in Terraform**
   - **Issue**: Creating a circular dependency between web_server and app_server resources
   - **Solution**: Used dependency management with depends_on attribute and null_resources where appropriate

2. **SSH Connection Issues**
   - **Issue**: Difficulty connecting from Jenkins to the web server and from web server to app server
   - **Solution**: Verified key permissions (chmod 600), added proper firewall rules, and ensured Cloud NAT was configured correctly

3. **Jenkins Pipeline Failures**
   - **Issue**: Test failures due to missing dependencies
   - **Solution**: Modified the Build stage to properly set up a Python virtual environment and install all required dependencies

4. **Nginx Configuration**
   - **Issue**: Web server not properly forwarding requests to the application
   - **Solution**: Corrected the proxy_pass configuration with the proper private IP address and ensured proper header forwarding

5. **Grafana API Authentication**
   - **Issue**: API authentication preventing programmatic access
   - **Solution**: Configured custom.ini with anonymous access and disabled API authentication

## OPTIMIZATION

### Advantages of Separating Deployment from Production
Separating deployment from production environments provides several benefits:
1. **Risk Reduction**: Changes can be tested in a deployment environment before affecting production
2. **Quality Assurance**: Comprehensive testing in a staging environment catches issues before they reach users
3. **Performance Testing**: Load and stress testing can be performed without impacting real users
4. **Training**: New team members can practice deployments without fear of breaking production

### Does This Infrastructure Address These Concerns?
This infrastructure partially addresses these concerns by:
- Separating components with different security requirements (public vs. private subnets)
- Implementing automated testing and security scanning in the pipeline
- Using infrastructure-as-code for consistent deployments

However, it lacks a complete staging environment that mirrors production.

### Is This a "Good System"?
While this system implements many best practices like:
- Network segmentation (public/private subnets)
- Automated CI/CD pipeline
- Security scanning
- Monitoring

It has several limitations:
- Single points of failure in each component
- No high availability or load balancing
- SQLite database (not ideal for production)
- Limited scalability

### Optimization Recommendations
To optimize this infrastructure, I would:
1. **Implement High Availability**: Deploy redundant instances across multiple zones
2. **Add Load Balancing**: Use a Google Cloud Load Balancer in front of multiple web servers
3. **Upgrade Database**: Replace SQLite with Cloud SQL or other managed database service
4. **Add Instance Groups**: Implement managed instance groups with autoscaling
5. **Create Staging Environment**: Add a complete staging environment that mirrors production
6. **Implement Blue-Green Deployments**: For zero-downtime deployments
7. **Add Cloud Armor and Cloud CDN**: For improved security and performance
8. **Implement Secrets Management**: Use Secret Manager for sensitive data
9. **Container Migration**: Consider migrating to Google Kubernetes Engine for better orchestration

## CONCLUSION

This project successfully demonstrates deploying a Flask application in a secure Google Cloud infrastructure using modern DevOps practices. The separation of components between public and private subnets, implementation of a CI/CD pipeline, and addition of monitoring create a solid foundation for application deployment.

The experience gained from this project provides valuable insight into cloud architecture design, infrastructure-as-code, and DevOps practices in the Google Cloud ecosystem. While the current implementation has limitations in terms of high availability and scalability, it serves as an excellent learning opportunity and starting point for more advanced infrastructure designs.

For a production environment, the optimization recommendations outlined above would need to be implemented to ensure reliability, scalability, and security. Nonetheless, this project represents a significant step forward from traditional deployment methods and demonstrates the value of infrastructure-as-code and CI/CD pipelines in modern application deployment on Google Cloud Platform.