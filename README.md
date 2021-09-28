# Infrastructure Engineer Work Sample


## Synopsis
This is a Docker image based on Ubuntu 18.04 that creates an NGINX server running the [Sample Payment Frame](https://github.com/spreedly/sample-payment-frame) over https.


* You must have Docker installed to run this container.

## Technical Overview
This project consists of two major parts, the ```nginx.conf``` configuration file and the ```Dockerfile```. A third file, ```docker-compose.yml```, makes it easier to spin up a container directly from the Dockerfile. Finally, ```build.sh``` automates building an image when run from the current directory.

My first task was to create an ```nginx.conf``` file based upon the limited needs of the Sample Payment Form application. It is thoroughly commented and each line was written intentionally. It limits MIME types, hides the NGINX version in headers, establishes rate-limiting, uses minimal buffers, shortens timeouts, and optimizes packet sizes. Other improvements include removing insecure ciphers and using TLSv1.2 and TLSv1.3 only. I made a decision to keep 2048-bit encryption due to the huge performance overhead of a 4096-bit key, so to prevent the [LogJam Exploit](https://weakdh.org), it uses Diffie-Hellmann Parameters. SSL handshakes are cached for 4 hours to improve performance, and the browser uses a ticket to validate the session. Since the application being served is static, caching headers are sent.

The program's ```Dockerfile``` takes a base Ubuntu 18.04 image and sets configurable values as ARG parameters. It performs an apt-get on the packages it will need to support the application and compile NGINX, then removes the sources and caches, as this image will not need them again. It generates an SSL certificate, as well as the Diffie-Hellmann parameters required to secure the application. These parameters are generated early in the ```Dockerfile``` layers to avoid repeating this time-consuming process unnecessarily. NGINX is then retrieved, compiled, and installed without unnecessary modules. Docker installs ```nginx.conf```, and the logs are forwarded back to Docker by symbolic link.

A running container launches NGINX in the foreground and terminates if it is closed.

## Quick Start

Use the included ```docker-compose.yml``` file to run a server quickly on **Port 8000** of your local machine. Navigate to the project folder in your terminal, then run:
```
docker-compose -up
```
## Long Start
Turn the project into a Docker image by navigating to the project folder in your terminal and executing:
```
docker build -t sample-payment-frame .
OR
./build.sh
```


Once the image is added to your registry by following the previous task, use the ```docker``` command to launch the project.
```
docker run -dp <LocalPort>:443 payment-frame
```
## Using the Payment Frame
Open a web browser and navigate to https://localhost:8000 (or whatever port you mapped it to.)

The generated SSL certificate is self-signed, so you'll need to add a browser exception to view the project. On Chrome, you can enable insecure localhost by navigating to chrome://flags/#allow-insecure-localhost

## Some things I'd do differently in Production

| Thing | What I'd want to do differently |
|---------------- | -----------|
|SSL Certificate | A certificate signed by a legitimate CA is essential for containers deployed from this image|
|File system | Read the files from a S3 bucket or other file host, and keep a local cache|
|Firewalling | I'd want some sort of edge device sitting outside to do intrusion detection|
|Worker connections| NGINX worker connections are set low for development and should closely align with ulimit -n output|
|Rate Limiting| NGINX rate limiting does not accurately reflect a Production environment and is set high for testing|
|Outbound limits| There should be egress restrictions|
|Flow| This code should be committed to a dev branch, tested, pushed to master, then pushed out to production|
|Testing | Automated testing should verify the image performs properly prior to deployment|
|[User Account]((https://www.rockyourcode.com/run-docker-nginx-as-non-root-user/)| NGINX could be configured to bind on higher ports so it wouldn't need to be initiated by root)|
|Build on update | This would be stored on a repo and an update would trigger rebuilds|
|Monitoring| This should be monitored by Data Dog or some other service|
| Orchestration | This should be used with Kubernetes or similar to manage large numbers of containers|
|Load Balancing | Something should be distributing requests between multiple containers according to load |
| [OCSP Stapling](https://www.digicert.com/kb/ssl-support/nginx-enable-ocsp-stapling-on-server.htm) | This would address some privacy concerns and remove a performance bottleneck|
|Log Aggregation | Right now the logs are just going to STDOUT and STDERR. They should be forwarded to a service, even Splunk would do|
|Vulnerability Checks| Once it has a valid certificate and exposed to the Internet, it should be checked on Qualys or some service that assesses security|

## Author
* [**Peter Thomas**](https://www.peterkthomas.com)
