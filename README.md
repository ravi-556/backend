1) copy local ssh private key to server
```
scp -i ~/.ssh/ec2-connector.pem ~/.ssh/id_ed25519_ravi556 ec2-user@<server-public-address>:~/.ssh/
```

3) create config file in .ssh folder and copy this code
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

```
git clone git@github-ravi556:ravi-556/backend.git
```

6) give permissions for deploy.sh and psql.sh
```
chmod +x deploy.sh
chmod +x psql.sh
```
7) run psql.sh
   ```
    ./psql.sh
   ```
   
8) run deploy.sh
```   
./deploy.sh
```

testing installation if no errors
```
curl -X POST http://localhost:9292/posts \
  -H "Content-Type: application/json" \
  -d '{
    "post_title": "My First Post",
    "post_content": "This is the content of the post",
    "author_name": "ravi",
    "published_id": "pub-123",
    "user_id": 1
  }'
```

