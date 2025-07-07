1) copy local ssh private key to server
```scp -i ~/.ssh/ec2-connector.pem ~/.ssh/id_ed25519_ravi556 ec2-user@<server-public-address>:~/.ssh/```

2) create config file in .ssh folder and copy this code
```
Host github-ravi556
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_ravi556
    IdentitiesOnly yes
```

3) give permissions to ssh files
```
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/config
```

4) install git
```
sudo yum update -y
sudo yum install git -y
```

5) clone repo

```git clone git@github-ravi556:ravi-556/backend.git```

6) give permissions for deploy.sh
```chmod +x deploy.sh```

7) run deploy.sh
```./deploy.sh
```
