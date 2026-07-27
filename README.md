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

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).
