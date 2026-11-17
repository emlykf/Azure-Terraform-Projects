# Deployment

## Prerequisites

- Azure subscription with permission to create resource groups, app registrations and role assignments
- GitLab account (identity verified, so shared runners can run pipelines)
- Git Bash (Windows) or any bash terminal
- Azure CLI and Terraform 1.17.x

## Step 1: Fork the project, clone it and log in to Azure

The pipeline has to run in your own GitLab project. Open this project in GitLab and click **Fork**. This creates a copy in your account with all files: the Terraform code, the pipeline and the scripts.

Download your fork to your computer (replace `<your-username>`):

```bash
git clone git@gitlab.com:<your-username>/azure-terraform-gitlab-cicd.git
cd azure-terraform-gitlab-cicd
```

Log in to Azure and select the subscription. Check that **Name** shows the right subscription before continuing:

```bash
az login 
az account set --subscription "<your-subscription-name>"
az account show --output table
```

## Step 2: Create the state backend
 
Terraform keeps a state file, its record of what it has already created. The state file lives in an Azure storage account, so your computer and the GitLab pipeline both use the same one.
 
The script runs with your own Azure login from Step 1, not with the pipeline identity. Your account sets up the foundation once (resource groups, storage, roles), and the pipeline later works with much fewer rights.
 
Storage account names must be globally unique. Before running the script, change `RG` and `SA` at the top of `scripts/bootstrap-state.sh`, and use the same names in the `backend` block of `terraform/providers.tf`.
 
The script creates:
- The **state resource group**, which only holds the storage account.
- The **storage account** for the state file, with key access turned off (only Entra ID logins work), versioning and soft delete.
- A **role for your own Azure account** (Storage Blob Data Contributor) on that storage account. Because key access is off, your login needs this role to read and write the state when you run Terraform on your computer.
- The `tfstate` **container** that holds the state file.
- The **project resource group** `rg-gitlab-cicd`. It stays empty for now. The pipeline identity is only allowed to work inside this resource group and can't create one itself, so it has to exist first. Terraform doesn't create it either: `main.tf` only looks it up with a `data` block (`rg-${var.prefix}`) and creates the VNet, NIC and VM inside it. If you change `prefix` in `terraform/variables.tfvars`, change the resource group name in both scripts too.
```bash
bash scripts/bootstrap-state.sh
```
 
The script finishes with the output `Done. State backend is ready.`

## Step 3: Create the SSH key for the VM

The VM only allows SSH key login, no password. Terraform writes the public key into the VM when it's created, so the key has to exist before the first plan. The `.pub` file is the public key that goes to Azure; the private key stays on your computer.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_vm_gitlab_cicd -C "vm-gitlab-cicd"
```

The VM has no public IP, so it can't be reached from the internet. To log in with this key, you'd need to add a way in, such as Azure Bastion.

## Step 4: Test locally with terraform plan

Go to the Terraform folder and store two values as environment variables in this terminal window. Terraform reads them automatically: `ARM_SUBSCRIPTION_ID` tells it which subscription to use, and `TF_VAR_ssh_public_key` fills the `ssh_public_key` variable with your public key. The commands print nothing, and the values are gone when you close the terminal.

```bash
cd terraform
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519_vm_gitlab_cicd.pub)"
```

> To see which ones are set in your current window: 
```bash
env | grep -E "ARM_|TF_VAR_"
```

Connect to the state backend, check formatting and syntax, and show what would be created. Nothing is created yet. The plan should end with `Plan: 4 to add, 0 to change, 0 to destroy.`

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Go back to the repo root for the next steps:

```bash
cd ..
```

## Step 5: Create the pipeline identity

Before running the script, change `GITLAB_PROJECT` at the top of `scripts/bootstrap-identity.sh` to your own project path (`<your-username>/azure-terraform-gitlab-cicd`), and the resource names if you changed them in Step 2.

The script creates the app registration (no secret), a federated credential that only trusts your project's `main` branch, and two roles: Contributor on the project resource group and Storage Blob Data Contributor on the state storage.

```bash
bash scripts/bootstrap-identity.sh
```

The script finishes with the output `ARM_CLIENT_ID`, `ARM_TENANT_ID` and `ARM_SUBSCRIPTION_ID`. You need these values in the next step.

## Step 6: Set up GitLab
 
**Protect the main branch**
 
Only `main` is allowed to deploy to Azure, so only maintainers should be able to change it, and its history shouldn't be rewritten.
 
1. In your GitLab project, go to **Settings → Repository → Branch rules**.
2. Click **Add branch rule**, choose **Branch name or pattern**, enter `main` and click **Create branch rule**.
3. Set **Allowed to merge** and **Allowed to push and merge** to **Maintainers**, and turn **Allow force push** off.
**Lock down the pipeline variables**
 
Nobody should be able to start a pipeline with their own values (for example a different subscription), and merge request pipelines only check the code, so they don't need any Azure access.
 
1. Go to **Settings → CI/CD → Variables**.
2. Under **Minimum role to use pipeline variables**, select **No one allowed** and click **Save changes**.
3. Uncheck **Allow merge request pipelines to access protected variables and runners** and click **Save changes**.
**Add the variables**
 
These tell the pipeline which identity, tenant and subscription to log in to, to use OIDC instead of a secret, and which SSH key to put on the VM. They're protected, so they only reach pipelines on `main`.
 
Click **Add variable** for each one. For all of them: Type **Variable**, Environments **All (default)**, **Protect variable** on, **Expand variable reference** off.
 
- `ARM_CLIENT_ID`: value from the Step 5 output, Visibility **Masked**
- `ARM_TENANT_ID`: value from the Step 5 output, Visibility **Masked**
- `ARM_SUBSCRIPTION_ID`: value from the Step 5 output, Visibility **Masked**
- `ARM_USE_OIDC`: value `true`, Visibility **Visible**
- `TF_VAR_ssh_public_key`: output of `cat ~/.ssh/id_ed25519_vm_gitlab_cicd.pub` (the whole line), Visibility **Visible**

## Step 7: Run the pipeline

Push your changes to `main`, which starts the pipeline:

```bash
git add .
git commit -m "Initial setup"
git push -u origin main
```

Then in GitLab:
1. Go to **Build → Pipelines** and open the newest pipeline.
2. Wait until `terraform_validate`, `trivy_config_scan` and `terraform_plan` have passed.
3. Open the `terraform_plan` job and check the end of the log. It should say `Plan: 4 to add, 0 to change, 0 to destroy.`
4. Go back to the pipeline and click **Run** on `terraform_apply` only (not "Run all manual"). The log should end with `Apply complete! Resources: 4 added, 0 changed, 0 destroyed.`

## Step 8: Verify in Azure

List the resources in the project resource group. You should see the VNet, NIC, VM and its OS disk:

```bash
az resource list --resource-group rg-gitlab-cicd --query "[].{name:name, type:type}" -o table
```

Check the VM size, that password login is disabled, and that Trusted Launch (Secure Boot, vTPM) is on:

```bash
az vm show --resource-group rg-gitlab-cicd --name vm-gitlab-cicd \
  --query "{size:hardwareProfile.vmSize, passwordLoginDisabled:osProfile.linuxConfiguration.disablePasswordAuthentication, secureBoot:securityProfile.uefiSettings.secureBootEnabled, vTPM:securityProfile.uefiSettings.vTpmEnabled}" -o table
```

Check that the VM only has a private IP and no public IP:

```bash
az vm list-ip-addresses --resource-group rg-gitlab-cicd --name vm-gitlab-cicd -o table
```

## Step 9: Destroy and clean up

1. In GitLab, open the pipeline and click **Run** on `terraform_destroy`.
2. The log should end with `Destroy complete! Resources: 4 destroyed.`

Check that the project resource group is empty. The state storage stays, so the pipeline can run again later:

```bash
az resource list --resource-group rg-gitlab-cicd -o table
```

**Full cleanup** (only when the project is no longer needed)

Delete the project resource group and the state backend (use your names from Step 2):

```bash
az group delete --name rg-gitlab-cicd --yes
az group delete --name rg-test01-gwc --yes
```

Delete the pipeline identity and its federated credential:

```bash
az ad app delete --id $(az ad app list --display-name "sp-gitlab-cicd" --query "[0].appId" -o tsv)
```