#!/bin/bash
# scripts/jenkins_setup.sh
# Consolidated script for Jenkins setup and configuration

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install necessary packages
sudo apt install -y openjdk-17-jdk git python3 python3-pip python3-venv unzip
sudo pip3 install pytest virtualenv

# Add the Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start Jenkins service
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Save the private key for Jenkins to use
sudo mkdir -p /var/lib/jenkins/.ssh
echo "${private_key_content}" | sudo tee /var/lib/jenkins/.ssh/id_rsa > /dev/null
sudo chmod 600 /var/lib/jenkins/.ssh/id_rsa
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh

# Install OWASP Dependency Check
echo "Installing OWASP Dependency Check..."
sudo rm -rf /opt/dependency-check
sudo mkdir -p /opt
cd /opt/
sudo wget https://github.com/jeremylong/DependencyCheck/releases/download/v6.5.3/dependency-check-6.5.3-release.zip
sudo unzip dependency-check-6.5.3-release.zip
sudo chmod -R 755 /opt/dependency-check
sudo chown -R jenkins:jenkins /opt/dependency-check

# Wait for Jenkins to be fully up
echo "Waiting for Jenkins to be fully up..."
sleep 10

# Get the admin password
ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Jenkins initial admin password: $ADMIN_PASSWORD"

# Download Jenkins CLI
cd /home/ubuntu
wget -q -O jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar
chmod +x jenkins-cli.jar

# Install necessary plugins
echo "Installing necessary plugins..."
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD install-plugin workflow-aggregator git junit dependency-check-jenkins-plugin pipeline-stage-view blueocean docker-workflow pipeline-github-lib pipeline-rest-api ssh-agent -deploy

# Restart Jenkins
echo "Restarting Jenkins..."
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD safe-restart

# Wait for Jenkins to restart
echo "Waiting for Jenkins to restart..."
sleep 30

# Create Multibranch Pipeline job
echo "Creating Multibranch Pipeline job..."
cat > job_config.xml << 'EOL'
<?xml version='1.1' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject plugin="workflow-multibranch@2.26">
  <actions/>
  <description></description>
  <properties>
    <org.jenkinsci.plugins.pipeline.modeldefinition.config.FolderConfig plugin="pipeline-model-definition@1.9.3">
      <dockerLabel></dockerLabel>
      <registry plugin="docker-commons@1.19"/>
    </org.jenkinsci.plugins.pipeline.modeldefinition.config.FolderConfig>
  </properties>
  <folderViews class="jenkins.branch.MultiBranchProjectViewHolder" plugin="branch-api@2.7.0">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </folderViews>
  <healthMetrics>
    <com.cloudbees.hudson.plugins.folder.health.WorstChildHealthMetric plugin="cloudbees-folder@6.16">
      <nonRecursive>false</nonRecursive>
    </com.cloudbees.hudson.plugins.folder.health.WorstChildHealthMetric>
  </healthMetrics>
  <icon class="jenkins.branch.MetadataActionFolderIcon" plugin="branch-api@2.7.0">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </icon>
  <orphanedItemStrategy class="com.cloudbees.hudson.plugins.folder.computed.DefaultOrphanedItemStrategy" plugin="cloudbees-folder@6.16">
    <pruneDeadBranches>true</pruneDeadBranches>
    <daysToKeep>-1</daysToKeep>
    <numToKeep>-1</numToKeep>
  </orphanedItemStrategy>
  <triggers>
    <com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger plugin="cloudbees-folder@6.16">
      <spec>H/5 * * * *</spec>
      <interval>300000</interval>
    </com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger>
  </triggers>
  <disabled>false</disabled>
  <sources class="jenkins.branch.MultiBranchProject$BranchSourceList" plugin="branch-api@2.7.0">
    <data>
      <jenkins.branch.BranchSource>
        <source class="jenkins.plugins.git.GitSCMSource" plugin="git@4.11.0">
          <id>1234567890</id>
          <remote>https://github.com/elmorenox/microblog-vpc-deployment-gcp.git</remote>
          <credentialsId></credentialsId>
          <traits>
            <jenkins.plugins.git.traits.BranchDiscoveryTrait/>
          </traits>
        </source>
        <strategy class="jenkins.branch.DefaultBranchPropertyStrategy">
          <properties class="empty-list"/>
        </strategy>
      </jenkins.branch.BranchSource>
    </data>
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </sources>
  <factory class="org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
    <scriptPath>Jenkinsfile</scriptPath>
  </factory>
</org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
EOL

echo "Creating job 'workload_4'..."
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD create-job workload_4 < job_config.xml

# Configure Dependency Check tool with simple groovy script
cat > configure-dp-check.groovy << 'EOL'
def dcDesc = Jenkins.instance.getDescriptorByName("org.jenkinsci.plugins.DependencyCheck.DependencyCheckDescriptor")
if (dcDesc) {
  def installation = new org.jenkinsci.plugins.DependencyCheck.DependencyCheckInstallation("DP-Check", "/opt/dependency-check", [])
  dcDesc.setInstallations(installation)
  dcDesc.save()
  println "Dependency-Check tool configured successfully."
}
EOL

echo "Configuring OWASP Dependency Check tool..."
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD groovy = < configure-dp-check.groovy || echo "Failed to configure OWASP Dependency Check tool. You may need to configure it manually."

echo "Jenkins configuration complete!"
echo "Your Multibranch Pipeline 'workload_4' has been created."
echo "Initial admin password: $ADMIN_PASSWORD"
echo ""
echo "Make sure your Jenkinsfile has the correct configurations for Python virtual environment and testing!"