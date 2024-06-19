# 🏖️ evertrust-playground

## Description

This repository aims to bootstrap an environment to demonstrate the use of EverTrust's products.

## Components

The distribution packages the following components by default :

- A Stream instance, preconfigured with a software key vault.
- An Horizon instance, preconfigured with enrollment profiles and Stream as a PKI connector.

It can also use **profiles** to add components to the installation dynamically. Refer to the [Profiles](#profiles) section for more information.

## Setup

As this project is based on Docker Compose, the only requirement is to have a fairly recent Docker engine installed locally. It supports both arm64 and amd64 architectures. Bootstrapping the project is straightforward :

1. The first step is to clone the repository to your local machine :
    ```
    git clone https://github.com/evertrust/playground.git
    ```

1. Then, you'll need to configure licenses for both Stream and Horizon. The Compose project expects the following license files to be present :
   - `stream.lic` in the `stream/license` directory : The Stream license file
   - `horizon.lic` in the `horizon/license`: The Horizon license file

1. Configure DNS entries to resolve to your local computer. The simplest way is to edit your `/etc/hosts` file, but you could also use a local DNS server such as `dnsmasq` :
    ``` 
    127.0.0.1 horizon.lab
    127.0.0.1 stream.lab
    ```

1. Docker will need to fetch Horizon, Stream and binaries from an authenticated repository. Copy the `.env.example` file to `.env` :
   ```bash
   cp .env.example .env
   ```
   And replace the contents of the file with your credentials, such as :
   ```dotenv
   REPOSITORY_USER=<your username>
   REPOSITORY_PASSWORD=<your password>
   ```
   Once done, you'll need to login to the registry :
    ```bash
    source .env
    docker login registry.evertrust.io -u $REPOSITORY_USER -p $REPOSITORY_PASSWORD
    ```

1. Finally, you can start the project :
    ```
    docker compose up -d
    ```

> Make sure ports 80 and 443 are not already in use on your local machine.

WARNING: When starting the project for the first time, Compose will need to build the containers from scratch. It may fail if you haven't bootstrapped a Buildx runner first with :
```bash
docker buildx create --use --bootstrap --name local
```

## Usage

The following services are exposed once the project is up and running :
- Horizon : https://horizon.lab
- Stream : https://stream.lab

To log in, if you opted in for database seeding, a default administrator account is created on both products. The default credentials are `administrator` / `evertrust`.

## Profiles

Profiles is a Docker Compose feature used to enable or disable components on the fly. It allows the installation to stay lightweight while taking many scenarios into account in this playground.

To enable a profile, pass the `--profile` parameter to the `docker compose` command :
```bash
docker compose --profile <profile> up -d
```

### client

#### Description

`client` boots a container with the EverTrust client installed. It is useful to test the client's integration with Horizon and Stream.

#### Setup
To gain access to the webserver running in the container, add the following line to your `/etc/hosts` :
```
127.0.0.1 webserver.lab
```

#### Demo scenario

1. Navigate to https://webserver.lab:8443. A bogus certificate should be presented.
   
1. Run a shell into the container :
   ```bash
   docker compose exec demo-client bash
   ```
1. Run the automation script :
   ```bash
   horizon-cli automate enroll --automation-policy DemoAutomationPolicyServer
   ```
   
1. After validating the enrollment, the https://webserver.lab:8443 should present an Horizon-issued certificate.

### ansible

#### Description

`ansible` boots a container with the Ansible collection installed. 

#### Demo scenario

1. Run a shell into the container :
   ```bash
   docker compose exec demo-ansible bash
   ```

1. Run `ansible-playbook` to install a webserver and provision a certificate for it :
   ```bash
   ansible-playbook playbook-deploy-apache.yaml
   ```
