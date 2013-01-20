rake-builder
============

*Rake for C, C++, Objective-C and Objective-C++ Projects*

* [Source code]
* [Documentation]
* [Rubygem]

[Source code]:   http://github.com/joeyates/rake-builder         "Source code at GitHub"
[Documentation]: http://rdoc.info/projects/joeyates/rake-builder "Documentation at Rubydoc.info"
[Rubygem]:       http://rubygems.org/gems/rake-builder           "Ruby gem at rubygems.org"

Hello World! Example
====================

(See the 'examples' directory for source).

Rakefile:
```ruby
require 'rubygems' if RUBY_VERSION < '1.9'
require 'rake/builder'

Rake::Builder.new do |builder|
  builder.target = 'hello_world_cpp'
end
```

main.cpp
```cpp
#include <iostream>

int main(int argc, char *argv[]) {
  std::cout << "Hello World!\n";

  return 0;
}
```

The Hello World! project should build and run:

```shell
$ rake run
Hello World!
```

Installation
============

Dependencies
------------

* makedepend
 * linux: package 'xutils-dev'
 * OS X: already installed

Gem
---

```shell
$ (sudo) gem install rake-builder
```

Usage
=====

Examples
--------
See the 'examples' directory.

If you've installed the gem system-wide, type the following to go to
the correct directory:

```shell
$ cd `gem environment gemdir`/gems/rake-builder-nnn
$ cd examples
```

Project Configuration
---------------------

In order to build on a specific computer, you will need
to indicate information like non-standard
include paths.

Rake::Builder collects all such information in one file:
'.rake-builder'

This file should be created in the same directory as the Rakefile.

The file should be a YAML structure, and must include a version.

Currently, the following can be configured:
* extra include paths: :include_paths
* extra compilation options (e.g. defines): :compilation_options

### Example '.rake-builder'

```yaml
---
:rake_builder:
  :config_file:
    :version: "1.0"
:include_paths:
- /opt/local/include
- /usr/include/c++/4.2.1
```

Default Tasks
-------------

* compile
* build
* run - executables only
* install
* clean

Installing Headers
------------------

If you install a static library, your headers will also be installed.
Ensure that you use file globs, e.g. './include/**/*.h',
as these will ensure that your headers are installed in the correct subdirectories.

Project
=======

Status
------

* Builds C, C++ and Objective-C projects using [GCC](http://gcc.gnu.org/).

Dependency Resolution
---------------------

Task dependencies must ensure that out of date files are recreated as needed.

![rake-builder Dependency Resolution](http://github.com/downloads/joeyates/rake-builder/RakeBuilderDependencyStructure.png "rake-builder Dependency Resolution")

Limitations
-----------

### File Modification Times

Rake's FileTask decides whether a file needs rebuilding by comparing on disk file
modification times (see the private method *out_of_date?*, which returns true if the
dependency was modified *after* the dependent).
Unfortunately, most modern file systems hold modification times in whole
seconds. If a dependency and a dependent were modificed during the same second,
**even if the dependency were modified later**, *out_of_date?* returns *false*
which is not the correct answer.

This problem is mostly felt in testing, where file modification times are temporarily
modified to test dependencies. Also, tests wait for second to complete after building.

#### File Modification Time Resolutions

* [Ext3](http://en.wikipedia.org/wiki/Ext3) - resolution: 1s
* [Ext4](http://en.wikipedia.org/wiki/Ext4) - resolution: 1 microsecond
* [Hierarchical_File_System](http://en.wikipedia.org/wiki/Hierarchical_File_System) - resolution: 1s
* [HFS_Plus](http://en.wikipedia.org/wiki/HFS_Plus) - resolution: 1s

### Source Files with the Same Name

Currently, object files from all source files are placed in the same directory.
So, if there are two source files with the same name, they will overwrite each other.

Alternatives
------------

* GNU build system, a.k.a. Autotools: autoconf, configure, make, etc.
* [Boost.Build](http://www.boost.org/boost-build2/)
* [CMake](http://www.cmake.org/)
* [SCons](http://www.scons.org/)
* [waf](http://code.google.com/p/waf/)
* [fbuild](https://github.com/felix-lang/fbuild)

