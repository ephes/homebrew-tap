# Ephes Tap

Personal Homebrew tap.

## How do I install these formulae?

`brew install ephes/tap/<formula>`

Or `brew tap ephes/tap` and then `brew install <formula>`.

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "ephes/tap"
brew "<formula>"
```

## Formulae

### `jpegli`

The Jpegli JPEG encoder (`cjpegli`), which produces smaller files than a
baseline JPEG encoder at the same perceptual quality — most usefully in the
0.5–1.5 bits/pixel range.

Homebrew core does not provide it. The official `jpeg-xl` formula builds with
`-DJPEGXL_ENABLE_JPEGLI=OFF`, so installing `jpeg-xl` gives you `cjxl` and
`djxl` but no `cjpegli` — see
[libjxl#3360](https://github.com/libjxl/libjxl/issues/3360).

jpegli was split out of libjxl into its own repository and has **no tagged
releases**, so this formula pins an exact commit:

```
github.com/google/jpegli @ 031a0077f5799a6041004267fc12b956c1f52a20  (2026-06-01)
```

The pin is deliberate and should not be bumped casually: it is the commit whose
output was measured and visually reviewed for the Daybook Photos reclamation
work, so changing it would invalidate those measurements.

Builds against Homebrew's `highway` and `little-cms2` rather than jpegli's
bundled submodules, with tests, benchmarks, JNI, OpenEXR and sjpeg disabled.
Takes about ten seconds.

Verified: the resulting `cjpegli` produces byte-identical output to a manual
build from the same commit.

## Validation

Pull requests and pushes to `main` run read-only Homebrew test-bot validation
on Linux, Intel macOS and Apple Silicon macOS. In addition to tap syntax/audit
checks, each run explicitly builds and tests `ephes/tap/jpegli`, the tap's
only formula (a regression guard requires updating CI when another is added).
Naming it avoids an empty changed-formula selection on branch
pushes and also validates workflow-only changes. On Intel macOS, where Homebrew
no longer bottles the dependencies, test-bot skips the formula, so the
regression step builds it from source before testing. Bottle publication
remains a separate manual workflow.

The package smoke encodes an in-memory synthetic 4×4 RGB gradient at the existing
`-d 1.0` setting, decodes it with the declared `jpeg-turbo` dependency's `djpeg`,
and checks 4×4 RGB dimensions, complete pixel data and mean absolute channel
error below 20 (on the 0–255 scale). No image downloads are needed. Regression
tests execute the formula's actual test block against real codecs, including
a two-byte JPEG, incorrect dimensions, black output and a missing encoder.

After installing the formula and `minitest` 6.0.0 for Ruby 4.0 or newer, run locally:

```sh
JPEG_TURBO_BIN="$(brew --prefix jpeg-turbo)/bin" \
  JPEGLI_BIN="$(brew --prefix jpegli)/bin" \
  ruby test/validation_test.rb
brew style Formula/jpegli.rb
brew audit --strict ephes/tap/jpegli
brew test ephes/tap/jpegli
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).
