# Flickr-Clone-Infrastructure

This repository contains Terraform code for provisioning Azure infrastructure. The infrastructure is used for hosting a _Flickr_ clone app

## 🏗️ Infrastructure diagram

![alt text](https://github.com/ahmedhussiien/flickr-infrastructure/blob/master/architecture.png?raw=true)

## 💡 Features

- [x] Remote Terraform backend.
- [x] Jenkins server provisioning and configuration.
- [x] Redis server for distributed cache.
- [x] Mongodb server with authentication.
- [x] Databases internal access only.
- [x] DNS records for webservers, and Jenkins.
- [x] SSLs for public domains.
- [x] Alerts for high CPU usage.
- [ ] Database replica set.
- [ ] Web servers scale set.
