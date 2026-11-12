# nix-github-ci

GitHub Actions CI generation for NixOS flakes — the generic engine behind a
fleet's `.github/workflows/ci.yml`, evaluated from Nix.

Part of the Bargman-Tech shared library family ([mayo](https://github.com/Bargman-Tech/mayo)
holds the topology/configuration surface; this repository holds the CI
domain). Consumption follows the same pattern as the fleet-standard
[`platonic/gitlab-ci.nix`](https://gitlab.com/platonic/gitlab-ci.nix):
a flake input, a library call, and re-exported apps.

## Usage

Add the input:

```nix
nix-github-ci = {
  url = "github:Bargman-Tech/nix-github-ci";
  inputs.nixpkgs.follows = "nixpkgs_stable";
};
```

Generate your workflow definition from `self` (machine lists are derived
from `nixosConfigurations` at eval time — no hardcoded lists), passing your
fleet data explicitly:

```nix
ci = nix-github-ci.lib.mkCi {
  inherit self lib;
  pkgs = nixpkgs;
  parallelism = { default.max-parallel = 10; };
  fleet = {
    exclusions = [ "cluster-box" "some-test-vm" ];
    profileTarget = "a-builder";      # eval-profiler step; null = omit
    x86TimeoutMinutes = 720;
    ipScanExcludes = [ "10.x.y.0" ];  # security-scan allowlist
  };
};
```

Re-export the generator apps (gitlab-ci style) and write the workflow:

```nix
apps.x86_64-linux = {
  inherit (nix-github-ci.apps.x86_64-linux)
    generate-ci-workflow validate-ci-workflow;
};
```

```bash
nix run .#generate-ci-workflow > .github/workflows/ci.yml
nix run .#validate-ci-workflow
```

## Fleet knobs (`fleet = { … }`)

Everything the workflow knows about *your* fleet arrives through this
argument — this repository deliberately carries no machine names, IPs, or
timeouts of its own.

| Knob | Type | Default | Purpose |
|---| list of string | `[ ]` | machines excluded from all CI builds |
| `profileTarget` | string \| null | `null` | target of the eval-profiler diagnostic step (flake eval flamegraph); `null` omits the step |
| `x86TimeoutMinutes` | int | `360` | `timeout-minutes` on the x86 build matrix (large caches need hours) |
| `ipScanExcludes` | list of string | `[ ]` | extra `grep -v` patterns for the hardcoded-IP security scan; emitted before the generic `127.0.0.1` / `documentation` excludes |

## Library surface

| Export | Shape |
|---|---|
| `lib.mkCi` | `{ self, lib, pkgs, parallelism?, fleet? } → { ci = { github-actions; github-actions-filtered; machines; jobs }; }` |
| `lib.ciLibrary` | path to the raw builders (`mkMatrixJob`, `formatNixOptions`, `resolveNixSettings`, `generateGitHubActions`, workflow scripts) for custom assembly |
| `apps.generate-ci-workflow` | writes the workflow JSON→YAML from `.#ci.ci.github-actions` of the **current directory's** flake |
| `apps.validate-ci-workflow` | yq + actionlint validation of `.github/workflows/ci.yml` |

The consumer typically keeps a CI golden (sorted JSON of
`ci.github-actions`) validated by its own `check-ci` app — that golden and
the workflow file stay on the consumer side.

## Checks

```bash
nix flake check   # formatting (nixpkgs-fmt) + deadnix
```

## License

AGPL-3.0-or-later — same as [mayo](https://github.com/Bargman-Tech/mayo).
