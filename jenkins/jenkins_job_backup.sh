aws s3 sync s3://test-demo-2003/jenkins-backup/ /tmp/jenkins-restore/
sudo mkdir -p /var/lib/jenkins/jobs/job1
sudo cp /tmp/job1_config.xml /var/lib/jenkins/jobs/job1/config.xml
sudo chown -R jenkins:jenkins /var/lib/jenkins/jobs/job1
sudo systemctl restart jenkins
rsync -a /var/lib/jenkins/jobs/ ~/jenkins-backup/
aws s3 sync ~/jenkins-backup/ s3://test-demo-2003/jenkins-backup/
find /var/lib/jenkins/jobs/ -name config.xml
aws s3 ls s3://test-demo-2003/jenkins-backups/ --recursive
