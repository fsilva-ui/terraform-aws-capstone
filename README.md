# AWS Hybrid Cloud Disaster Recovery — Terraform Capstone Project

## Overview

This capstone project explores the design and implementation of a secure hybrid cloud disaster recovery solution using AWS and Terraform.

The project is based on a real-world infrastructure scenario in which business-critical applications and documents are primarily hosted on-premises. The goal is to design a disaster recovery architecture that can maintain access to critical services during infrastructure failures while preserving data security, privacy, and consistency.

The AWS environment is implemented as a separate lab environment using test data only. No production or patient data is used.

## Business Problem

The existing on-premises environment contains two main infrastructure systems:

- A VMware ESXi server hosting several virtual machines and business applications
- A Synology NAS providing document storage and hosting Docker workloads

Some services depend on both systems. This creates several potential failure scenarios.

For example, documents used by therapists are stored on the Synology NAS and exposed to Nextcloud through SMB External Storage.

Administrative users access synchronized versions of these documents through Microsoft 365.

During a Synology outage, administrative users may therefore continue working through Microsoft 365 while therapists lose access through Nextcloud.

A disaster recovery solution must restore access without creating conflicting writable copies of the same documents.

## Project Goal

The goal of this project is to design and implement an AWS-based disaster recovery environment for selected business-critical workloads.

The solution focuses on:

- Hybrid cloud architecture
- Infrastructure as Code
- Disaster recovery
- Backup and restore
- Network isolation
- Data consistency
- Security and encryption
- Monitoring
- Controlled failover and failback

## Current Environment

### Compute

The on-premises environment uses VMware ESXi to host several virtual machines.

Important workloads include:

- Nextcloud
- Docuseal
- LimeSurvey
- Printer monitoring services

### Storage

A Synology NAS provides shared document storage.

The document storage is used by:

- Nextcloud through SMB External Storage
- Microsoft 365 through synchronization

This allows different user groups to access the documents through different platforms.

### Container Workloads

The Synology NAS also hosts Docker applications used for:

- Prevention course management, bookings and planning
- Digital collection of T-RENA treatment signatures

These applications are accessible only from the internal company network and must not be publicly exposed.

## Workload Criticality

### Critical Workloads

**Nextcloud**

Provides internal communication through Nextcloud Talk and document access for therapists using mobile devices.

**Docuseal**

Supports digital patient registration and data protection documentation workflows.

**T-RENA Application**

Collects digital treatment signatures and is currently hosted as a private Docker workload.

### Important Workloads

**Prevention Course Application**

Supports course management, bookings and planning.

### Lower-Priority Workloads

**LimeSurvey**

Used for patient satisfaction surveys on dedicated tablets.

**Printer Monitoring**

Monitors printer toner levels and supports toner replacement planning.

These workloads do not require the same recovery priority as the business-critical applications.

## Disaster Scenarios

The project considers several infrastructure failure scenarios.

### ESXi Host Failure

Potentially affects:

- Nextcloud
- Nextcloud Talk
- Docuseal
- LimeSurvey
- Printer monitoring

### Synology Failure

Potentially affects:

- Shared documents
- Nextcloud SMB External Storage
- T-RENA application
- Prevention course application

Administrative users may still have access to synchronized documents through Microsoft 365.

### Complete On-Premises Failure

A larger incident may make both compute and storage infrastructure unavailable.

The AWS disaster recovery environment is designed to provide recovery options for selected critical services.

## Data Consistency Challenge

Document recovery presents an additional challenge.

Under normal operation:

```text
                    Synology
                       |
              Shared Documents
                 /           \
               SMB         Cloud Sync
                |              |
            Nextcloud     Microsoft 365
                |              |
            Therapists    Administration
```

During a Synology outage, Microsoft 365 may remain available and administrative users can continue modifying documents.

Creating an independent writable disaster recovery copy for therapists could therefore result in conflicting versions.

The disaster recovery design must maintain a clearly defined authoritative data source and include a controlled failback procedure.

## Proposed AWS Architecture

The final AWS architecture is currently being designed.

Potential AWS services include:

- Amazon VPC
- Amazon EC2
- Amazon ECS / Fargate
- Amazon ECR
- Amazon S3
- Amazon RDS
- Amazon EFS
- AWS Site-to-Site VPN
- AWS Backup
- AWS KMS
- AWS Secrets Manager
- Amazon CloudWatch
- AWS CloudTrail
- Amazon Route 53

The final selection of services will be based on technical requirements, security, recovery objectives, and cost.

## Infrastructure as Code

AWS infrastructure is managed using Terraform.

The project uses:

- Terraform
- Terraform Cloud
- GitHub

Infrastructure changes follow the workflow:

```text
GitHub
   |
   v
Terraform Cloud
   |
   v
Terraform Plan
   |
   v
Terraform Apply
   |
   v
AWS
```

The objective is to make the disaster recovery infrastructure reproducible and minimize manual configuration.

## Security Principles

The architecture follows several security principles:

- Least-privilege IAM permissions
- Private subnets for internal workloads
- No public exposure of sensitive internal applications
- Encryption at rest and in transit
- Centralized secrets management
- Network segmentation
- Logging and monitoring
- No production patient data in the AWS lab environment

## Disaster Recovery Strategy

The project will evaluate appropriate recovery strategies for each workload rather than applying the same strategy to every service.

The recovery process will cover:

```text
Backup / Replication
        |
        v
Failure Detection
        |
        v
Disaster Recovery Activation
        |
        v
Restore Critical Services
        |
        v
Validate Applications and Data
        |
        v
Temporary AWS Operation
        |
        v
Controlled Failback
        |
        v
Return to On-Premises Operation
```

Recovery Point Objectives (RPO) and Recovery Time Objectives (RTO) will be defined and tested for selected workloads.

## Technologies

- AWS
- Terraform
- Terraform Cloud
- GitHub
- Docker
- VMware
- Synology
- Microsoft 365
- Nextcloud

## Repository Structure

The repository structure will evolve as the implementation progresses.

Planned structure:

```text
.
├── README.md
├── terraform/
├── architecture/
├── documentation/
├── scripts/
└── .github/
```

## Project Status

🚧 **In Progress**

Current phase:

**Architecture and disaster recovery design**

Next steps:

1. Finalize workload dependencies
2. Define RPO and RTO requirements
3. Design the AWS network architecture
4. Select AWS services for each workload
5. Implement the base infrastructure with Terraform
6. Implement backup and recovery workflows
7. Test disaster scenarios
8. Test failback and data consistency
9. Document results and costs
10. Prepare the final capstone presentation

## Disclaimer

This project is an educational proof of concept.

The architecture is inspired by a real business environment, but the AWS implementation uses only test systems and synthetic data.

No real patient or production data is used.