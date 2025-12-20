# Setup For Self-Guided Learners

Use this guide if you are working on these labs on your own at home!

---

## 📋 1. Pre-Requisites

You will need:

- A personal GitHub account - [signup here for free](https://github.com/signup)
- 발급받은 Azure 계정 확인 -  [signup here for free](https://portal.azure.com/)
- A laptop with a modern browser - we recommend Microsoft Edge
- Some familiarity with - Git, VSCode, Python & Jupyter notebooks
- Some familiarity with - Generative AI concepts and workflows

<br/>

## 🚀 2. 개발 환경 구성

First, let's get you set up with a development environment for the lab. The repository is setup with a `devcontainer.json` that provides a pre-build development environment with all tools and dependencies installed. Let's activate that in three steps!

### 2.1. Fork This Repo

1. [이 저장소](https://github.com/haew0nsh1n/ignite25-PREL13-observe-manage-and-scale-agentic-ai-apps-with-microsoft-foundry/fork)를 개인 저장소로 포크합니다. 
1. 앞으로 이 저장소의 msignite2025-kor 포크를 실습에 사용합니다.
1. 브라우저를 열고 이 저장소 파일을 탐색합니다.

### 2.2. VS Code IDE 구동

1. 포크한 자신의 저장소를 git 명령어를 사용해서 로컬 디렉토리에 다운로드 합니다.
    ```bash title="" linenums="0"
    git clone -b msignite2025-kor --single-branch https://github.com/<USERNAME>/ignite25-PREL13-observe-manage-and-scale-agentic-ai-apps-with-microsoft-foundry 
    ```
1. VS Code IDE를 구동하고 이 디렉토리를 오픈합니다.

### 2.3. Authenticate With Azure

1. Open a terminal in that VS Code session - wait till prompt is active
1. Run this command - follow steps to complete auth with **your** subscription

    ```bash title="" linenums="0"
    az login
    ```

    ```bash title="" linenums="0"
    azd login
    ```
1. When flow is complete, return to VS Code - accept default subscription

_Your development environment is ready - and connected to Azure!_

<br/>

## ⚙️ 3. Provision Your AI Agents Resources

1. We'll jumpstart our development using the [Get Started With AI Agents](https://github.com/Azure-Samples/get-started-with-ai-agents) template
1. This provides a solution architecutre with sample code & infrastructure files
1. We created a _custom_ version of this template that you can install with scripts.

_Let's get this done_

1. Open a new VS Code Terminal. Complete these steps:

    ```bash
    cd scripts
    ./1-setup.sh
    ```
1. Then complete the interactive steps providing responses like this:

    1. Enter branch name: `for-release-1.0.4`
    1. Enter environment name (고유한 자신의 환경을 입력하세요): `Ignite-PREL13`
    1. Enter Azure region: `swedencentral`
    1. Enter Subscription ID: _your subscription id here_
    1. Do you want to activate Azure AI Search? (yes/no) [no]: yes
    1. Use these defaults? (yes/no) [yes]: yes
    1. Proceed with deployment? (yes/no): yes

1. When complete you should see:

    1. A `scripts/ForBeginners/` folder cloned from a template repo
    1. A `scripts/ForBeginners/.azd-setup` with infrastructure files
    1. A `scripts/ForBeginners/.azd-setup/.azure` with infra env config

<br/>

**TROUBLESHOOTING:**

1. You may see issues related to "bicep" not being available. To fix, do the following:
    ```bash
    cd ForBeginners/.azd-setup
    azd up
    ```

    This completes azd deployment directly and ends with something like this:

    ```bash
    SUCCESS: Your up workflow to provision and deploy to Azure completed in 12 minutes 39 seconds.
    ```

1.  You may get a deployment error part way through 

    ```bash
    Deployment Error Details:
    RequestConflict: Cannot modify resource with id '/.../providers/Microsoft.CognitiveServices/accounts/aoai-t7sla5j64lcvo' because the resource entity provisioning state is not terminal
    ```

    This is typically caused by a timing issue where a previous resource task has not completed. The best way to resolve this is to back off and try again. So just wait a few minutes, then retry this - and it should complete.

    ```bash
    azd up
    ```

<br/>

## ⚙️ 4. Set up `.env` variables.

1. Make sure you are authenticated with Azure CLI.  We will use this to retrieve and create a `.env` file based on the `scripts/.env.sample` format

    ```bash
    az login
    ```

1. Run this script from root of repo - it will create `.env` with values extracted by Azure CLI. _By default it looks for an `rg-Ignite-XXX` resource group but you can override it.

    ```
    ./scripts/1-update-env-selfguided.sh 
    ``````

<br/>

## 📊 5. Populate Search Data

1. We have Zava data in `scripts/customization`. Let's create a product index in Azure AI Search. Switch to the `scripts/` folder and run the command:

    ```
    cd scripts/
    python 2-add-product-index.py 
    ```

1. This will first run an RBAC update script to give this user the right roles and access to make updates.
1. Then it should upload 49 products to a `zava-products` index with semantic search, in Azure AI Search.

<br/>

## 🎓 6. Add Model Choices

The default AI Agents template will deploy one chat model. The AI Search index creation will require a second text-embedding model.

In addition, we want to be able to show _model selection_ with evaluators and graders - so we want to have a suitable set of model choices available. This script makes that happen.

1. Update the `scripts/customization/add-models.json` with the list of models you want to choose from, for deployments

1. Run this script and provide the selection you actually want deployed:

    ```bash
    cd scripts/
    ./2-add-model-choices.sh 
    ```

1. On success you should see:

    ```bash
    ========================================
    Add Additional Model Deployments
    (Using .env file)
    ========================================

    ℹ️  Checking prerequisites...
    ...
    ...

    ✓ Added ADDITIONAL_MODEL_DEPLOYMENTS to .env file

    ========================================
    Deployment Summary
    ========================================
    ✓ model-router deployed
    ✓ gpt-4o deployed
    ✓ gpt-4o-mini deployed
    ✓ gpt-4.1-mini deployed
    ✓ gpt-4.1-nano deployed
    ✓ o3-mini deployed
    ✓ o4-mini deployed
    ========================================

    ✓ Model deployment completed successfully!
    ```

1. It will also update the `.env` file with the relevant variable and list:

```bash
ADDITIONAL_MODEL_DEPLOYMENTS=[{"name":"model-router","model":{"format":"OpenAI","name":"model-router","version":"2025-05-19"},"sku":{"name":"GlobalStandard","capacity":20}},{"name":"gpt-4o","model":{"format":"OpenAI","name":"gpt-4o","version":"2024-11-20"},"sku":{"name":"GlobalStandard","capacity":20}},{"name":"gpt-4o-mini","model":{"format":"OpenAI","name":"gpt-4o-mini","version":"2024-07-18"},"sku":{"name":"GlobalStandard","capacity":20}},{"name":"gpt-4.1-mini","model":{"format":"OpenAI","name":"gpt-4.1-mini","version":"2025-04-14"},"sku":{"name":"GlobalStandard","capacity":20}},{"name":"gpt-4.1-nano","model":{"format":"OpenAI","name":"gpt-4.1-nano","version":"2025-04-14"},"sku":{"name":"GlobalStandard","capacity":20}},{"name":"o3-mini","model":{"format":"OpenAI","name":"o3-mini","version":"2025-01-31"},"sku":{"name":"GlobalStandard","capacity":20}},{"name":"o4-mini","model":{"format":"OpenAI","name":"o4-mini","version":"2025-04-16"},"sku":{"name":"GlobalStandard","capacity":20}}]
```

<br/>

```


## ✅ 7. Validate your `.env` variables

1. It's easy - there's a notebook for that!
1. Open `labs/0-setup/00-validate-setup.ipynb` in your Visual Studio Code editor.
1. Select Kernel - pick the default Python environment
1. "Run All" - to have validation checks run.

```bash
============================================================
📊 VALIDATION SUMMARY
============================================================
✅ Valid variables: 47
❌ Missing variables: 0

🎉 All environment variables are properly configured!
   You're ready to proceed with the lab exercises.
```


## 🔄 8. (Optional) Refresh Env From Existing Infra

What if you had provisioned infrastructure earlier - but had deleted your Codespaces? Can you _restore_ environment variables from an existing infrastructure?

Yes. Note that the `scripts/1-update-env-selfguided.sh` script only needs your subscription and a resource group, and it can retrieve and update your `.env`. 

<br/>

## 📚 9. Complete Your Labs

_Your infrastructure is now ready! You can now launch the instruction guide and start working through the labs!_.

1. Open a new terminal in VS Code.
1. Type `mkdocs serve` - wait a few seconds to see the pop-up dialog
1. Confirm you want to open this in browser.
1. _You should see an instruction guide for labs in website preview_. 

**Start with the Validate Setup lab - then keep going**:

1. First, run the `0-setup/00-validate-setup.ipynb` notebook
1. Verify that all required environment variables were set!
1. Then keep going down the list in the instruction guide.


<br/>

## 🧹 10. Teardown & Cleanup

When you are all done with labs, you want to tear down the infrastructure _and_ delete the cloned template sources from your repo. Make sure you are in the `scripts/` folder then run this command:

```bash title="" linenums="0"
./3-teardown.sh
```

You will see:

```bash title="" linenums="0"
Starting teardown process...
Found ForBeginners directory
Checking for AZD environments...
Found AZD environment: nitya-Ignite-PREL13
======================================
WARNING: This will delete all Azure resources
======================================
Tear down Azure infrastructure? (yes/no): 
```

Respond with "yes" - and wait till complete. This will take 15-20 minutes to unprovision the resource group and purge resources. _You can now use the `./1-setup.sh` script if you want to restart install from scratch_.

---

## 🆘 Troubleshooting

### Common issues and solutions

| Issue | Solution |
|-------|----------|
| **Script fails with "Not logged in"** | Run `az login` again and complete authentication |
| **Resource group not found** | Ensure you're using the correct Azure subscription |
| **MkDocs won't start** | Try `pip install -r requirements-dev.txt` first |
| **Notebook kernel not found** | Select the Python kernel from the top-right kernel picker |
| **Bicep deployment fails** | Navigate to `ForBeginners/.azd-setup` and run `azd up` directly |
| **Model deployment conflicts** | Wait a few minutes and retry with `azd up` |

### Additional resources

- �🐛 [Report issues on GitHub](https://github.com/Azure-Samples/ignite25-PREL13/issues)
- 💬 Join our community on Discord to interact with other developers:

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/3cmBfTFkH7)

---

**🎉 Congratulations!** Your lab environment is ready. Start exploring the power of Azure AI Foundry!