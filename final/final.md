# Services

## gitlab
I grabbed the docker compose file from Gitlab's officiall documentation. I 
changed the ports to ones that made sense to me. It's important to note that 
the external HTTP port has to match the internal one or it won't work with 
CI/CD. I'm not positive why, but I think it has to do with how the links are
generated. 

It takes a while to spin up, but once it does you can log in with the creds
root:<password in config/initial_root_password>. I changed the admin password
right away because the `initial_root_password` file says that the password is
invalid after 24 hours. 

Then I created a user. Normally it's supposed to send the new user and email
asking them to set their password, but I didn't want to set up SMTP. Instead, 
as soon as the user is created, you can change their password as the admin and
they can sign in with that. When they sign it, it will ask them to change their
password, and then it works as expected. 

![ user created page ](./img/gitlab-user.png)

Once I had a user, I was able to create a repository, clone it, and push to it
as normal. (You can also have a repo as admin, but...)

```
$ git clone ssh://git@systemsec-04.cs.pdx.edu:7022/sawyeras/test.git
Cloning into 'test'...
remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Compressing objects: 100% (2/2), done.
remote: Total 3 (delta 0), reused 0 (delta 0), pack-reused 0 (from 0)
Receiving objects: 100% (3/3), done.

 $ cd test
 $ vim tmp.file
 $ git add .
 $ git commit -m "testing"
[main 9179774] testing
 1 file changed, 1 insertion(+)
 create mode 100644 tmp.file

 $ git push origin main
Enumerating objects: 4, done.
Counting objects: 100% (4/4), done.
Delta compression using up to 24 threads
Compressing objects: 100% (2/2), done.
Writing objects: 100% (3/3), 301 bytes | 150.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
To ssh://systemsec-04.cs.pdx.edu:7022/sawyeras/test.git
   1a48635..9179774  main -> main
```

![updated gitlab repo](./img/gitlab-push.png)


### Docker
```
services:
  gitlab:
    image: gitlab/gitlab-ce:18.0.6-ce.0
    container_name: gitlab
    restart: always
    hostname: 'gitlab'
    environment:
      TZ: 'America/Los_Angeles'
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://systemsec-04.cs.pdx.edu:7080'
    ports:
      - '7080:7080'
      - '7022:22'
      - '4000:4000' # jekyll
    volumes:
      - './config:/etc/gitlab'
      - './logs:/var/log/gitlab'
      - './data:/var/opt/gitlab'
    shm_size: '256m'
```

NOTE:
changed config to make internal ports match internal and change http to
https. add tz to make cookie check work. then CLEAR COOKIES or it won't
realize it's been fixed...

## bitwarden
I used the vaultwarden image rather than bitwarden since that was supposed
to be easier to set up. 

I tried to set up vaultwarden with HTTPS using DuckDNS created certificates. 
That did not work. Instead, I was able to access vaultwarden with ssh port
forwards and then accessing it on `http://localhost`. 

```
 $ ssh -NL 80:192.168.33.66:80 bsd
```

![vaultwarden login](./img/vw-login.png)

![vaultwarden page](./img/vw-page.png)

### Docker
```
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    environment:
      # DOMAIN: "https://vaultwarden.example.com/"  # required when using a reverse proxy;
      SIGNUPS_ALLOWED: "true" # Deactivate this with "false" after you have created account
    volumes:
      - ./vw-data:/data # the path before the : can be changed
    ports:
      - 80:80
```

## Frigate
I got the docker compose file from a guide that Logan showed me. Once I spun it
up, I was able to get the credentials from the logs and login. I stopped there 
because I don't actually have a camera to hook it up to. 

![frigate dashboard](./img/frigate-page.png)

### Docker
```
services:
  frigate:
    container_name: frigate
    restart: unless-stopped
    stop_grace_period: 30s
    image: ghcr.io/blakeblackshear/frigate:stable
    volumes:
      - ./config:/config
      - ./storage:/media/frigate
      - type: tmpfs # Optional: 1GB of memory, reduces SSD/SD Card wear
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    ports:
      - "8971:8971"
      - "8554:8554" # RTSP feeds
```

## Jekyll
set up a runner according to docs

grabbed gitlab example repo for jekyll

upgrade
install sudo and vim
link git to reasonable location
-> `ln -s /opt/gitlab/embedded/bin/git /usr/local/bin/git 2>/dev/null || true; git --version`
install ruby-full and build-essential
added gitlab runner to passwdless sudo
made custom clone url to http://localhost:7080 for runner

.gitlab-ci.yml
	sudo gem install
	local bundle install
	CI job started working

able to see generated site when running jekyll serve from CI script. Little
funky, but it's just a POC? 

# Terraform + Ansible
kept having a problem with noble0 running out of memory while I was working 
on the gitlab + jekyll stuff. changed it so noble0 has 6-8G and bsd has 2-2.5G
