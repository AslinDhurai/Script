# Automation Scripts

This directory contains operational automation used for cloud infrastructure, database administration, search platform maintenance, CI/CD support, and server operations.

The scripts are organized by service area and operating system to make ownership, review, and execution easier.

## Purpose

These scripts support common DevOps and operations tasks such as backups, cleanup, monitoring, patching, cost checks, snapshot validation, and system reporting.

They are intended to be reviewed, configured, and tested before use in production environments.

## Repository Structure

```text
Script/
├── aws/              # AWS automation
├── database/         # Database migration, monitoring, and replication
├── elasticsearch/    # Elasticsearch snapshot and restore operations
├── jenkins/          # Jenkins backup and restore operations
├── linux/            # Linux server maintenance
└── windows/          # Windows server maintenance
```

## Service Areas

### AWS

The `aws/` directory contains scripts for AWS resource operations.

It includes AMI backup automation, EC2 snapshot cleanup, RDS restore validation, EC2 scheduling, S3 storage reporting, VPC CIDR planning, and cost optimization.

Scripts in this area may create, stop, resize, restore, or delete AWS resources. Review the configured account, region, tags, bucket names, and IAM permissions before running them.

### Database

The `database/` directory contains scripts and notes for database operations.

The MySQL scripts handle schema migration and connection monitoring. The PostgreSQL documentation covers a Docker-based primary and replica setup.

Database scripts should be tested against non-production instances before use, especially migration and restore workflows.

### Elasticsearch

The `elasticsearch/` directory contains scripts for Elasticsearch snapshot management.

Elasticsearch is a search and analytics engine commonly used for logs, metrics, and fast application search. The scripts in this folder register snapshot repositories, create snapshots, remove old snapshots, validate restored snapshots, and publish snapshot job logs to CloudWatch.

Snapshot deletion and restore scripts should be reviewed carefully before execution.

### Jenkins

The `jenkins/` directory contains Jenkins job backup and restore commands.

These scripts interact with Jenkins job configuration files and S3 backup storage. Validate source and destination paths before restoring job configurations.

### Linux

The `linux/` directory contains Linux server operations scripts.

It includes cleanup tasks, Apache log compression and upload, disk usage alerts, inactive user reporting, system statistics collection, and security patch automation.

Some Linux scripts require elevated privileges and may delete files, truncate logs, restart swap, or update packages.

### Windows

The `windows/` directory contains PowerShell scripts for Windows server operations.

It includes cache cleanup, old file cleanup, disk usage alerts, and system statistics collection.

Run these scripts from an appropriate PowerShell session with the required execution policy and permissions.

## Execution Guidelines

Before running any script, confirm the following:

1. The script is being run in the intended environment.
2. Required tools and modules are installed.
3. Credentials and secrets are not hardcoded.
4. Resource names, regions, paths, and thresholds are correct.
5. Destructive actions have been reviewed and approved.

Common dependencies include `aws`, `boto3`, `curl`, `jq`, `mysql`, `sendmail`, and PowerShell modules.

## Security Standards

Do not store production secrets directly in scripts.

Move emails, passwords, access keys, database credentials, IP addresses, bucket names, webhook URLs, and environment-specific values into environment variables, parameter files, CI/CD secrets, or a secrets manager.

Use least-privilege IAM permissions for AWS scripts. Avoid running scripts with broad administrative access unless explicitly required and approved.

## Operational Risk

Scripts that delete, stop, restore, resize, patch, truncate, or overwrite resources must be treated as change-controlled operations.

Recommended practice:

1. Test in a non-production environment.
2. Take or verify backups before making changes.
3. Capture logs for audit and troubleshooting.
4. Run with a named operator or automation identity.
5. Document the expected outcome before execution.

## Running Scripts

Linux shell scripts:

```bash
chmod +x path/to/script.sh
./path/to/script.sh
```

Python scripts:

```bash
python3 path/to/script.py
```

PowerShell scripts:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\path\to\script.ps1
```

## Maintenance

When adding new scripts, place them in the appropriate service or platform directory.

Use clear filenames, avoid hardcoded production values, include comments for non-obvious logic, and document any required external tools or permissions.
