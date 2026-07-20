<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public entry point for rules_glyph.

Public API: examples and downstream users should load from this file instead of
`glyph/internal/...`. The internal files are free to move; this facade is the
compatibility contract.

<a id="glyph_binary"></a>

## glyph_binary

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_binary")

glyph_binary(<a href="#glyph_binary-name">name</a>, <a href="#glyph_binary-deps">deps</a>, <a href="#glyph_binary-data">data</a>, <a href="#glyph_binary-main_module">main_module</a>)
</pre>

Links Glyph libraries into an executable script.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="glyph_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="glyph_binary-deps"></a>deps |  Glyph libraries linked into this binary.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="glyph_binary-data"></a>data |  Extra runtime files available when the binary is launched.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="glyph_binary-main_module"></a>main_module |  Glyph module that provides the binary entry point.   | String | required |  |


<a id="glyph_debug_binary"></a>

## glyph_debug_binary

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_debug_binary")

glyph_debug_binary(<a href="#glyph_debug_binary-name">name</a>, <a href="#glyph_debug_binary-binary">binary</a>)
</pre>

Wraps a binary dependency behind an outgoing debug transition.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="glyph_debug_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="glyph_debug_binary-binary"></a>binary |  Glyph binary rebuilt with //glyph/settings:mode=debug.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="glyph_debug_report"></a>

## glyph_debug_report

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_debug_report")

glyph_debug_report(<a href="#glyph_debug_report-name">name</a>, <a href="#glyph_debug_report-deps">deps</a>)
</pre>

Reports the module list under a rule-level (incoming) debug transition, so mode=debug without any command-line flag.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="glyph_debug_report-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="glyph_debug_report-deps"></a>deps |  Glyph libraries whose module list is reported under the debug configuration.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="glyph_library"></a>

## glyph_library

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_library")

glyph_library(<a href="#glyph_library-name">name</a>, <a href="#glyph_library-deps">deps</a>, <a href="#glyph_library-srcs">srcs</a>, <a href="#glyph_library-data">data</a>, <a href="#glyph_library-exports">exports</a>, <a href="#glyph_library-module">module</a>)
</pre>

Compiles Glyph source files into a Glyph object and provider.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="glyph_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="glyph_library-deps"></a>deps |  Direct Glyph libraries used to compile and link this module.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="glyph_library-srcs"></a>srcs |  Glyph source files that declare exactly one module.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="glyph_library-data"></a>data |  Runtime files declared by resource statements and carried into binaries through runfiles.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="glyph_library-exports"></a>exports |  Glyph libraries re-exported to direct dependents, Java-style.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="glyph_library-module"></a>module |  Public Glyph module name provided by this target.   | String | required |  |


<a id="glyph_report"></a>

## glyph_report

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_report")

glyph_report(<a href="#glyph_report-name">name</a>, <a href="#glyph_report-deps">deps</a>)
</pre>

Routes report generation through a dedicated execution group pinned to the report worker pool.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="glyph_report-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="glyph_report-deps"></a>deps |  Glyph libraries included in the report.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="glyph_split_report"></a>

## glyph_split_report

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_split_report")

glyph_split_report(<a href="#glyph_split_report-name">name</a>, <a href="#glyph_split_report-binary">binary</a>)
</pre>

Demonstrates a dict-of-dicts split transition and reading per-branch configured settings via ctx.split_attr.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="glyph_split_report-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="glyph_split_report-binary"></a>binary |  Binary analyzed once for linux and once for macos branch keys.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="glyph_test"></a>

## glyph_test

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_test")

glyph_test(<a href="#glyph_test-name">name</a>, <a href="#glyph_test-binary">binary</a>, <a href="#glyph_test-expected">expected</a>)
</pre>

Runs a Glyph binary and checks one expected output line.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="glyph_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="glyph_test-binary"></a>binary |  Glyph binary to run under Bazel's test runner.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="glyph_test-expected"></a>expected |  Exact output line expected from the binary.   | String | required |  |


<a id="GlyphInfo"></a>

## GlyphInfo

<pre>
load("@rules_glyph//glyph:defs.bzl", "GlyphInfo")

GlyphInfo(<a href="#GlyphInfo-direct_modules">direct_modules</a>, <a href="#GlyphInfo-exported_modules">exported_modules</a>, <a href="#GlyphInfo-interface_objects">interface_objects</a>, <a href="#GlyphInfo-link_objects">link_objects</a>, <a href="#GlyphInfo-modules">modules</a>, <a href="#GlyphInfo-manifests">manifests</a>,
          <a href="#GlyphInfo-runtime_files">runtime_files</a>)
</pre>

Carries the compile, link, and runtime contract for Glyph libraries.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="GlyphInfo-direct_modules"></a>direct_modules |  depset of module names declared directly by this target; the source of truth exported_modules and modules are derived from.    |
| <a id="GlyphInfo-exported_modules"></a>exported_modules |  depset of modules visible to direct dependents through deps/exports; recorded in the compile manifest.    |
| <a id="GlyphInfo-interface_objects"></a>interface_objects |  depset of small interface objects (one module name each) read when compiling direct dependents, instead of the full link objects.    |
| <a id="GlyphInfo-link_objects"></a>link_objects |  depset of full compiled objects needed when linking binaries through this target.    |
| <a id="GlyphInfo-modules"></a>modules |  depset of Glyph module names linked through this target.    |
| <a id="GlyphInfo-manifests"></a>manifests |  depset of human-readable compile manifests, surfaced through the glyph_manifests output group.    |
| <a id="GlyphInfo-runtime_files"></a>runtime_files |  depset of files needed when linked Glyph binaries run.    |


<a id="glyph_legacy_app"></a>

## glyph_legacy_app

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_legacy_app")

glyph_legacy_app(<a href="#glyph_legacy_app-name">name</a>, <a href="#glyph_legacy_app-srcs">srcs</a>, <a href="#glyph_legacy_app-module">module</a>, <a href="#glyph_legacy_app-main_module">main_module</a>, <a href="#glyph_legacy_app-deps">deps</a>, <a href="#glyph_legacy_app-exports">exports</a>, <a href="#glyph_legacy_app-data">data</a>, <a href="#glyph_legacy_app-visibility">visibility</a>)
</pre>

Legacy macro that expands to a private glyph_library plus public glyph_binary.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="glyph_legacy_app-name"></a>name |  Name of the public binary target produced by the macro.   |  none |
| <a id="glyph_legacy_app-srcs"></a>srcs |  Glyph source files for the private helper library.   |  none |
| <a id="glyph_legacy_app-module"></a>module |  Glyph module name provided by the private helper library.   |  none |
| <a id="glyph_legacy_app-main_module"></a>main_module |  Glyph module used as the binary entry point.   |  none |
| <a id="glyph_legacy_app-deps"></a>deps |  Glyph libraries imported by the source module.   |  `[]` |
| <a id="glyph_legacy_app-exports"></a>exports |  Glyph libraries re-exported by the private helper library.   |  `[]` |
| <a id="glyph_legacy_app-data"></a>data |  Runtime files declared by the private helper library.   |  `[]` |
| <a id="glyph_legacy_app-visibility"></a>visibility |  Visibility applied to the public binary target.   |  `None` |


<a id="glyph_app"></a>

## glyph_app

<pre>
load("@rules_glyph//glyph:defs.bzl", "glyph_app")

glyph_app(*, <a href="#glyph_app-name">name</a>, <a href="#glyph_app-deps">deps</a>, <a href="#glyph_app-srcs">srcs</a>, <a href="#glyph_app-data">data</a>, <a href="#glyph_app-exports">exports</a>, <a href="#glyph_app-main_module">main_module</a>, <a href="#glyph_app-module">module</a>, <a href="#glyph_app-visibility">visibility</a>)
</pre>

Symbolic macro that expands to a private glyph_library plus public glyph_binary.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="glyph_app-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="glyph_app-deps"></a>deps |  Glyph libraries imported by the source module.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="glyph_app-srcs"></a>srcs |  Glyph source files for the private helper library.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `[]`  |
| <a id="glyph_app-data"></a>data |  Runtime files declared by the private helper library.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="glyph_app-exports"></a>exports |  Glyph libraries re-exported by the private helper library.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="glyph_app-main_module"></a>main_module |  Glyph module used as the binary entry point.   | String | required |  |
| <a id="glyph_app-module"></a>module |  Glyph module provided by the helper library.   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | required |  |
| <a id="glyph_app-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


