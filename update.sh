ruby update-csv.rb
scp -i dotwave.pem *.csv ec2-user@dotwave.johnholdun.com:/var/www/dotwave/
ssh -i dotwave.pem ec2-user@dotwave.johnholdun.com "cd /var/www/dotwave && ruby load-csv.rb"
