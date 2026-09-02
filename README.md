# Introduction

This repository contains a collection of Azure labs and automation projects built with Terraform. You’ll find a description of each project in its directory.

> [!NOTE]
> These labs will also contain what challenges I faced and how I resolved them.

## Prerequisites

Before you begin, you will need an [Azure subscription](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account?hasfullconsent=true) with Owner permissions and a [GitHub account](https://github.com/signup).

In addition, you will need the following tools installed on your local machine:

* [Visual Studio Code](https://code.visualstudio.com/download) with the following extensions:
  * [Microsoft Terraform extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azureterraform)
  * [HashiCorp Terraform extension](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform)
* [Git](https://git-scm.com/downloads)
* [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
* [Terraform CLI](https://developer.hashicorp.com/terraform/install)

## Login to Azure

```bash
az login
# or
az login --use-device-code
```

## Basic Commands:
> [!NOTE]
> I will use alias for most of my projects "alias tf=terraform".

- **`terraform init`**: Initializes a new or existing Terraform configuration. This command downloads the necessary provider plugins and prepares your working directory for use.
- **`terraform fmt`**: Formats your Terraform configuration files to ensure they are properly indented and follow best practices. This is useful for maintaining readability and consistency in your code.
- **`terraform validate`**: Validates your Terraform configuration files to ensure they are syntactically correct and can be applied without errors.
- **`terraform plan`**: Creates an execution plan, showing you what actions Terraform will take to achieve the desired state defined in your configuration. This is a dry-run command that does not make any changes to your infrastructure.
- **`terraform apply`**: Applies the changes required to reach the desired state of the configuration. This command will create, update, or delete resources as necessary and requires you to confirm the changes before proceeding.
- **`terraform destroy`**: Destroys the resources defined in your configuration. This command will remove all resources created by Terraform.