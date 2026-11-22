# Repository settings for automatic updates

Configure these settings in `chinrw/agy-cli-nix` so the hourly update workflow
opens pull requests and merges them after required CI checks pass.

## Workflow permissions

Under Settings -> Actions -> General, select read and write permissions for
workflows and enable "Allow GitHub Actions to create and approve pull requests".

## Update token

Create the repository Actions secret `UPDATE_TOKEN` with a personal access
token or fine-grained token that has `Contents: Read and write` and
`Pull requests: Read and write` on `chinrw/agy-cli-nix`. Pull requests opened
by `GITHUB_TOKEN` do not trigger pull-request CI workflows, so `UPDATE_TOKEN`
is required to trigger `test-pr.yml` and enable auto-merge.

## Auto-merge and branch rules

Enable **Allow auto-merge** and **Automatically delete head branches** under
Settings -> General -> Pull Requests.

Keep the `Require pull request CI` ruleset active on `main` with pull request
enforcement and required status checks for `test-build (ubuntu-latest)`,
`test-build (ubuntu-24.04-arm)`, and `test-build (macos-latest)`.

## Verify an update

Trigger and inspect the update workflow:

```sh
gh workflow run update.yml --repo chinrw/agy-cli-nix
gh run list --workflow=update.yml --repo chinrw/agy-cli-nix
```
