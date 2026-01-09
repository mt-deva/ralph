# CI/CD Grunt Reference Audit

## Summary

Audit of all Grunt references in CI/CD pipeline files, shell scripts, and Dockerfiles.

## Findings

### .gitlab-ci.yml
**No grunt references found.**

### Dockerfiles
**No grunt references found.**

The project has a single `Dockerfile` which does not reference grunt.

### Shell Scripts (build.sh)

Found **4 grunt calls** in `build.sh`:

| Line | Command | Purpose |
|------|---------|---------|
| 17 | `./node_modules/.bin/grunt sass` | Compile SCSS to CSS |
| 18 | `./node_modules/.bin/grunt compile` | RequireJS bundling (obsolete) |
| 19 | `./node_modules/.bin/grunt path-replace --force --base-path=$PUBLIC_PATH` | Replace paths for CDN |
| 22 | `./node_modules/.bin/grunt extend-config --bp=${CDN_PATH} --vhash=${VERSION_HASH} --build=${BUILD_TAG}` | Extend config.json with build metadata |

### package.json

Found grunt references in:

| Location | Reference | Purpose |
|----------|-----------|---------|
| scripts.postinstall | `grunt sass && pnpm compile-gql` | Compile SCSS on install |
| devDependencies | `grunt: 1.3.0` | Core Grunt |
| devDependencies | `grunt-contrib-connect: 2.1.0` | Dev server (unused?) |
| devDependencies | `grunt-contrib-requirejs: 1.0.0` | RequireJS compile task |
| devDependencies | `grunt-contrib-watch: 1.1.0` | File watching |
| devDependencies | `grunt-open: 0.2.4` | Open browser |
| devDependencies | `grunt-sass: 3.1.0` | SCSS compilation |
| devDependencies | `grunt-webpack: 5.0.0` | Webpack integration |
| devDependencies | `load-grunt-tasks: 5.1.0` | Task loader |

## Migration Impact

### Critical Path (Build Pipeline)
1. **grunt sass** - Must migrate to webpack sass-loader
2. **grunt compile** - Can be removed (RequireJS obsolete, webpack handles bundling)
3. **grunt path-replace** - Evaluate if webpack publicPath handles this
4. **grunt extend-config** - Replace with Node.js script

### Development Workflow
1. **postinstall grunt sass** - Replace with webpack or remove once migration complete
2. **grunt-contrib-watch** - Replace with webpack-dev-server

### Safe to Remove
- `grunt-contrib-connect` - Not used in build.sh
- `grunt-contrib-requirejs` - RequireJS is obsolete
- `grunt-open` - Not used in build.sh
- `grunt-webpack` - Can use webpack directly

## Recommended Migration Order

1. US-002: Remove RequireJS compile task
2. US-003-005: Configure webpack for SCSS
3. US-006: Create extend-config Node.js script
4. US-007: Evaluate path-replace
5. US-008: Remove grunt sass
6. US-009-011: Remove remaining grunt infrastructure
