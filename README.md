# devops-engineering-ci-public-build-independent-module-workflow

Reusable GitHub Actions workflow for building IQGeo modules with independent versioning.

## Overview

This workflow enables building and releasing IQGeo platform modules that have independent version lifecycles. It's designed for:

- Partner-maintained modules (e.g., Geo&Web integrations)
- Internal modules with independent release cadences
- Modules maintained in separate repositories

It differs from the standard module workflow by packaging the caller repository with either a generic or custom cut script instead of assuming the standard IQGeo module repository structure.

For inbound and outbound dependency relationships, see [docs/WHO-CALLS-WHAT.md](docs/WHO-CALLS-WHAT.md).

## Features

- ✅ **Independent versioning** - Each module has its own version and release schedule
- ✅ **Generic cut script** - Works out of the box for most modules
- ✅ **Custom cut script support** - Override with module-specific processing
- ✅ **Shared dockerfiles** - Centralized Dockerfile.injector and Dockerfile.QAappserver
- ✅ **Multi-arch support** - Leverages existing build-multi-arch-workflow
- ✅ **Azure artifact storage** - Stores cut binaries in Azure File Share

Current implementation note:

- The workflow can build QA images.
- The EKS redeploy job is currently commented out in the workflow file, so deployment is documented as adjacent behavior rather than active behavior.

## Usage

### In Your Module Repository

Create a workflow file `.github/workflows/build-{module}.yml`:

```yaml
name: Build My Module

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version (e.g., 1.0.0)'
        required: true
        type: string
  push:
    tags:
      - 'mymodule-v*'  # Auto-trigger on tags

permissions:
  id-token: write
  contents: read
  actions: read
  packages: write

env:
  MODULE: my_integration_module
  MODULE_PREFIX: mymodule

jobs:
  extract-version:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      is_release: ${{ steps.version.outputs.is_release }}
    steps:
      - name: Determine version
        id: version
        run: |
          # From workflow_dispatch
          if [[ -n "${{ inputs.version }}" ]]; then
            VERSION="${{ inputs.version }}"
          # From tag (mymodule-v1.0.0)
          elif [[ "${{ github.ref_name }}" =~ ^${MODULE_PREFIX}-v(.+)$ ]]; then
            VERSION="${BASH_REMATCH[1]}"
          else
            echo "❌ ERROR: No version specified"
            exit 1
          fi
          
          # Validate format
          if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
            echo "❌ ERROR: Invalid version format: $VERSION"
            exit 1
          fi
          
          # Determine release type
          if [[ "$VERSION" =~ (alpha|beta|rc) ]]; then
            IS_RELEASE="false"
          else
            IS_RELEASE="true"
          fi
          
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "is_release=$IS_RELEASE" >> $GITHUB_OUTPUT

  build:
    needs: extract-version
    uses: IQGeo/devops-engineering-ci-public-build-independent-module-workflow/.github/workflows/build-independent-module.yml@main
    with:
      version: ${{ needs.extract-version.outputs.version }}
      module: ${{ env.MODULE }}
      module_prefix: ${{ env.MODULE_PREFIX }}
      is_release: ${{ needs.extract-version.outputs.is_release }}
      engineering_prefix: "engineering"
      releases_prefix: "releases_mymodule"
      custom_cut_script: ""  # Use generic or specify path
      build_qa_images: true   # Build full platform+module images
      namespace: "qa-cyclomedia"  # Optional: K8s namespace
      pod_name: "cyclomedia-appserver"  # Optional: Pod to redeploy
    secrets: inherit
```

### Triggering Builds

**Option 1: Workflow Dispatch (Manual)**

1. Go to Actions tab in GitHub
2. Select your build workflow
3. Click "Run workflow"
4. Enter version (e.g., `1.0.0`)

**Option 2: Git Tags**

```bash
# Create and push a tag
git tag mymodule-v1.0.0
git push origin mymodule-v1.0.0
```

Tag format: `{module_prefix}-v{version}`

Examples:
- `cyclomedia-v1.0.0` - Release
- `cyclomedia-v1.1.0-alpha1` - Pre-release
- `cyclomedia-v1.0.1` - Patch release

## Workflow Inputs

| Input | Required | Description | Default |
|-------|----------|-------------|---------|
| `version` | Yes | Module version (e.g., 1.0.0) | - |
| `module` | Yes | Module name (e.g., cyclomedia_integration) | - |
| `module_prefix` | Yes | Short prefix for tags/paths (e.g., cyclomedia) | - |
| `is_release` | Yes | "true" for release, "false" for pre-release | - |
| `engineering_prefix` | No | ACR/Harbor path prefix | devops_sandbox_engineering |
| `releases_prefix` | No | Releases path prefix | devops_sandbox_releases |
| `custom_cut_script` | No | Path to custom cut script | "" (use generic) |
| `build_qa_images` | No | Build full platform+module images | false |
| `platform_version` | No | Platform version to build against | "7.4" |
| `namespace` | No | Kubernetes namespace for deployment | "" |
| `pod_name` | No | Kubernetes pod to redeploy | "" |

## How this repo fits the wider build stack

- Upstream: a caller workflow decides module-specific triggers and versioning.
- Downstream: this workflow relies on `devops-engineering-ci-public-build-multi-arch-workflow` for image publication.
- Adjacent: it shares the same registries and artifact storage model as the standard module build workflow, but relaxes repository layout assumptions.

## Custom Cut Scripts

By default, the generic cut script (`scripts/cut_module_generic.sh`) is used. It:

- Creates a tarball from your module directory
- Excludes common development files (.git, node_modules, etc.)
- Generates version_info.json

### When to Use a Custom Cut Script

Provide a custom cut script if you need to:

- Sanitize line endings or encoding
- Remove unshipped content (tests, docs)
- Add default configuration
- Transform source files before packaging

### Creating a Custom Cut Script

Create `scripts/cut_my_module.sh` in your repository:

```bash
#!/bin/bash
set -e

MODULE=$1
VERSION=$2
SOURCE_DIR=$3
OUTPUT_DIR=$4

echo "Running custom cut for $MODULE v$VERSION"

cd "$SOURCE_DIR/$MODULE"

# Custom processing
find . -type f -name "*.py" -exec dos2unix {} \;
rm -rf tests/ docs/

# Create tarball
tar czf "$OUTPUT_DIR/IQGeo_${MODULE}_${VERSION}.tar.gz" \
  --exclude='.git*' \
  --exclude='*.pyc' \
  .

# Generate version_info.json
echo "{\"${MODULE}\": \"${VERSION}\"}" > "$OUTPUT_DIR/version_info.json"

echo "✅ Custom cut completed"
```

Reference it in your workflow:
```yaml
custom_cut_script: "scripts/cut_my_module.sh"
```

## Repository Structure

### Module Repository (Your Repo)

```
my-integration-repo/
├── .github/workflows/
│   └── build-my-module.yml       # Caller workflow
├── deployment/
│   └── my-module/                # Deployment configuration
│       ├── dockerfile.build       # Platform build image (pulls injector)
│       ├── dockerfile.appserver   # Production appserver
│       ├── dockerfile.tools       # Worker/tools image
│       ├── docker-compose.yml    # Local test environment
│       ├── entrypoint.d/         # Initialization scripts
│       │   └── 600_init_db.sh
│       ├── .env.example
│       └── README.md
├── my_integration_module/        # Module source
│   ├── config/
│   ├── public/
│   ├── server/
│   └── ...
└── scripts/                      # Optional custom cut scripts
    └── cut_my_integration.sh
```

### This Repository (Reusable Workflow)

```
build-independent-module-workflow/
├── .github/workflows/
│   └── build-independent-module.yml    # Reusable workflow
├── scripts/
│   └── cut_module_generic.sh           # Generic cut script
├── dockerfiles/
│   ├── Dockerfile.injector              # Shared injector
│   └── Dockerfile.QAappserver           # Shared QA image
└── README.md
```

## Built Images

The workflow produces the following Docker images:

### Injector Image (Always Built)
- **Path:** `{engineering_prefix}/{module_prefix}/{module}:{version}`
- **Example:** `engineering/cyclomedia/cyclomedia_integration:1.0.0`
- **Contents:** Module source code only
- **Used by:** Build images, deployment processes
- **Built by:** `build-injector` job

### Platform Build Image (When build_qa_images=true)
- **Path:** `{engineering_prefix}/platform-{module_prefix}-build:{version}`
- **Example:** `engineering/platform-cyclomedia-build:1.0.0`
- **Contents:** Platform + module with built bundles and dependencies
- **Used by:** Creating appserver and tools images
- **Built by:** `build-platform-build` job

### Platform Appserver Image (When build_qa_images=true)
- **Path:** `{engineering_prefix}/platform-{module_prefix}-appserver:{version}`
- **Example:** `engineering/platform-cyclomedia-appserver:1.0.0`
- **Contents:** Production appserver with platform + module
- **Used by:** Deployment, testing environments
- **Built by:** `build-platform-components` job

### Platform Tools Image (When build_qa_images=true)
- **Path:** `{engineering_prefix}/platform-{module_prefix}-tools:{version}`
- **Example:** `engineering/platform-cyclomedia-tools:1.0.0`
- **Contents:** Worker/tools image with platform + module
- **Used by:** Background workers, scheduled tasks
- **Built by:** `build-platform-components` job

### QA Appserver Image (When build_qa_images=true)
- **Path:** `{engineering_prefix}/platform-{module_prefix}-qa-appserver:{version}`
- **Example:** `engineering/platform-cyclomedia-qa-appserver:1.0.0`
- **Contents:** QA-ready appserver (combined platform + module)
- **Used by:** QA testing, automated test environments
- **Built by:** `build-qa-appserver` job

## Workflow Jobs

The workflow executes the following jobs in sequence:

### 1. cut-module
- Checks out module source, workflow repo, and core platform
- Runs cut script (generic or custom) to create tarball
- Generates `version_info.json`
- Uploads artifacts to Azure File Share
- **Always runs**

### 2. build-injector
- Builds multi-arch injector image with module source
- Pushes to ACR and Harbor registries
- **Always runs** (depends on `cut-module`)

### 3. build-platform-build (Conditional)
- Pulls injector image
- Installs pip packages and node modules
- Builds client bundles
- Creates intermediate build image
- **Runs when:** `build_qa_images=true`
- **Depends on:** `build-injector`

### 4. build-platform-components (Conditional)
- Matrix job building two images:
  - `platform-{module_prefix}-appserver`
  - `platform-{module_prefix}-tools`
- Uses platform-build image as base
- **Runs when:** `build_qa_images=true`
- **Depends on:** `build-platform-build`

### 5. build-qa-appserver (Conditional)
- Builds QA-ready appserver image
- Combines platform components for testing
- **Runs when:** `build_qa_images=true`
- **Depends on:** `build-platform-components`

### 6. redeploy-eks-pod (Conditional)
- Triggers Kubernetes pod restart
- Pulls newly built images
- **Runs when:** `build_qa_images=true` AND `namespace` AND `pod_name` are set
- **Depends on:** `build-platform-components`

## Secrets Required

The following secrets must be configured in your repository:

- `GH_TOKEN` - GitHub token for accessing private repos
- `HARBOR_USERNAME` - Harbor registry username
- `HARBOR_CLI_SECRET` - Harbor registry password
- `REGISTRY_USERNAME` - ACR username
- `REGISTRY_PASSWORD` - ACR password
- `AZURE_STORAGE_ACCOUNT_KEY` - Azure storage key
- `AZURE_CREDENTIALS` - Azure service principal credentials

## Examples

See the [gwi-integrations](https://github.com/IQGeo/gwi-integrations) repository for a complete working example.

## Support

For issues or questions:
- **Workflow issues:** Open an issue in this repository
- **Platform questions:** Contact IQGeo DevOps team
- **Module-specific issues:** Contact module maintainer

## License

Internal use only - IQGeo Ltd.
Reusable workflow for building independent modules in a single repo
