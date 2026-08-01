#!/usr/bin/env bash
#
# Validates examples/* against the module in THIS repository rather than the
# published release.
#
# The committed examples source the published module so consumers can copy them
# verbatim from the Terraform Registry. Validating them as written would therefore
# check the last release rather than the working tree.
#
# Each example is copied to a temporary directory, its registry source is swapped
# for a path to this repository, and that copy is validated. Tracked files are
# never modified. CONTRIBUTING.md covers why this indirection exists.
#
# Uses grep/sed/perl rather than rg so it runs on a bare CI image.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
# Exported because the perl rewrite below reads it as $ENV{ROOT}.
export ROOT="$PWD"
root="$ROOT"

# Shared provider cache so each example does not re-download the provider.
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

status=0

for dir in examples/*/; do
  name="$(basename "$dir")"
  [ -f "${dir}main.tf" ] || continue

  tmp="$workdir/$name"
  mkdir -p "$tmp"
  cp -R "${dir}." "$tmp/"
  rm -rf "$tmp/.terraform" "$tmp/.terraform.lock.hcl"

  # Rewrite:
  #   source  = "terraform-temporalcloud-modules/<name>/temporalcloud"
  #   version = "~> 1.0"
  # into:
  #   source = "<repo root>"
  #
  # A `//subdir` suffix (e.g. //wrappers) is preserved as a path under the root.
  # The `version` line must go too: Terraform rejects it on a local source.
  perl -0pi -e '
    s{
      ^([ \t]*)source[ \t]*=[ \t]*"terraform-temporalcloud-modules/[^"/]+/[^"/]+(//[^"]+)?"[ \t]*\n
      [ \t]*version[ \t]*=[ \t]*"[^"]*"[ \t]*\n
    }{
      $1 . "source = \"" . $ENV{ROOT} . ($2 ? substr($2,1) : "") . "\"\n"
    }gmxe
  ' "$tmp"/*.tf

  # Guard: if the rewrite matched nothing, the published
  # module and silently lose the whole point of this script.
  if grep -q 'terraform-temporalcloud-modules/' "$tmp"/*.tf; then
    echo "ERROR: $dir still references the registry after rewrite." >&2
    echo "       The source address format probably changed; update this script." >&2
    status=1
    continue
  fi
  if ! grep -q "source = \"$root" "$tmp"/*.tf; then
    echo "ERROR: $dir has no local source after rewrite — nothing was validated." >&2
    status=1
    continue
  fi

  echo "==> $name (against local module)"
  if ! (cd "$tmp" && terraform init -backend=false -no-color >/dev/null 2>&1); then
    echo "ERROR: terraform init failed for $dir" >&2
    (cd "$tmp" && terraform init -backend=false -no-color 2>&1 | tail -20) >&2
    status=1
    continue
  fi
  if ! (cd "$tmp" && terraform validate -no-color); then
    status=1
  fi
done

exit $status
