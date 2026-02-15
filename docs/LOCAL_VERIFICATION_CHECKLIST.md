# Local Verification Checklist (pre-CI push)

Run these before pushing to catch regressions.

## 1. Lint and syntax
```bash
./test/run_tests.sh --lint-only
find . -name "*.sh" -type f ! -path "./.git/*" -exec bash -n {} \;
```

## 2. Shellcheck (key files)
```bash
shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 \
  lib/common_functions.sh install/consensus/nimbus.sh \
  install/execution/erigon.sh install/execution/reth.sh \
  install/consensus/grandine.sh install/web/install_caddy.sh \
  install/web/install_nginx.sh test/ci_test_e2e.sh test/run_e2e.sh
```

## 3. Function tests
```bash
# ensure_jwt_secret creates parent dir
# get_github_release_asset_url returns Nimbus URL
bash -c 'source lib/common_functions.sh; ensure_jwt_secret /tmp/t/jwt.hex; get_github_release_asset_url status-im/nimbus-eth2 nimbus-eth2_Linux_amd64'
```

## 4. Unit tests
```bash
bash install/test/test_common_functions.sh
USE_MOCKS=true ./test/docker_test.sh
```

## 5. CI workflow YAML
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"
```

## 6. Docker (if available)
```bash
docker build -t eth-node-test -f test/Dockerfile .
SKIP_BUILD=true ./test/run_e2e.sh --phase=2
```

## Last run: 2026-02-15
- Lint: 254 passed
- Syntax: all scripts valid
- Shellcheck: passed
- Caddy config: valid
- verify_client_configs: 28 passed
- ensure_jwt_secret: creates dir, works
- get_github_release_asset_url: returns Nimbus URL
- common_functions: 10/10 passed
- docker_test: 74 passed
- CI YAML: valid
