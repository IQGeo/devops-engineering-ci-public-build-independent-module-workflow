# Who Calls What

## Scope

This document shows the inbound and outbound workflow dependencies for `devops-engineering-ci-public-build-independent-module-workflow`.

## Matrix

| Direction | Component | Relationship | Notes |
| --- | --- | --- | --- |
| Called by | Caller workflow in an independent module repository | Inbound | Can be called directly from a module-specific workflow; versioning may be handled by custom caller logic or a local extract step |
| Uses | Generic cut script or caller-provided custom cut script | Internal | Chooses the custom script when present, otherwise falls back to `scripts/cut_module_generic.sh` |
| Calls | `devops-engineering-ci-public-build-multi-arch-workflow/.github/workflows/build-multi-arch.yml` | Direct | Builds the injector image |
| Calls | `devops-engineering-ci-public-build-multi-arch-workflow/.github/workflows/build-multi-arch.yml` | Optional | Reused for platform build, appserver, tools, and QA appserver images when `build_qa_images=true` |
| References | `devops-engineering-ci-redeploy-eks-pod/.github/workflows/redeploy-eks-pod.yml` | Inactive | The redeploy job exists as commented-out code in the current workflow file |

## Notes

- This workflow relaxes the repository layout assumptions used by the standard module workflow.
- The QA image chain is active, but the redeploy integration is currently not.