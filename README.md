---
display_name: Laravel (PHP 8.3)
description: Coder Template for Laravel (PHP 8.3)
icon: https://laravel.com/img/logomark.min.svg
maintainer_github: vkambulov
verified: true
tags: [docker, container, laravel, php]
---

# Remote Development for Laravel

[Coder Template](https://coder.com/docs/v2/latest/templates) for [Laravel](https://laravel.com) with PHP 8.3.

Work in progress. There may be some errors.

## Features

- Based on Ubuntu 22.04
- PHP 8.3
- Docker in Docker (DinD). You can use Sail or custom services in your projects.
- MySQL 8.0
- Cloning GitHub private repos with [Coder External Auth](https://coder.com/docs/v2/latest/admin/external-auth)
- [JetBrains Gateway](https://registry.coder.com/modules/jetbrains-gateway), [VS Code Desktop](https://registry.coder.com/modules/vscode-desktop) and [VS Code in the browser](https://code-server.dev)
- Sharing home directory between several projects
- [File Browser](https://registry.coder.com/modules/filebrowser)

## TODO

- Fix PHPMyAdmin work
- Download and unzip archive instead git clone for some repositories
- Postgresql support
  - pgAdmin
- Cron for Laravel
- Support custom configs for supervisor/cron/other
- Disabling `artisan serve` on startup
