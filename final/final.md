# Services

## gitlab

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
kevin says:
    don't need MTA -- set things that need it to no ops
    change gitlab port only if port conflict

NOTES:
spin up docker container 
login with root:<passwd in config/initial_root_password>
create user sawyeras
![ user created page ](./img/gitlab-user.png)
change password as admin to avoid email req
able to sign in as created user
able to create repo, clone, and push
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

changed root password because default gets removed after 24hrs? 

changed config to make internal ports match internal and change http to
https. add tz to make cookie check work. then CLEAR COOKIES or it won't
realize it's been fixed...

## bitwarden

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

domain -- need a domain name for ssl cert, usually handled w/ dynamic dns
	point at cs.pdx.edu/pdx.edu

Ended up just doing minimal config and then ssh port forwarding
ssh -NL 80:noble0:80 bsd



## Frigate

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

docker compose from logan

spin it up
get creds from logs
login
nothing to see bc no cameras

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
