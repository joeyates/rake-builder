require 'spec_helper'

describe Compiler::Base do
  context '.for' do
    it 'returns a compiler' do
      expect(Compiler::Base.for(:gcc)).to be_a(Compiler::GCC)
    end
  end

  subject { Compiler::Base.new }

  context '#include_paths' do
    before do
      File.stub(:exist?).
        with('/opt/local/include/foo/bar.h').
        and_return(false)
    end

    it 'checks extra paths' do
      File.should_receive(:exist?).
        with('/opt/local/include/foo/bar.h').
        and_return(true)

      subject.include_paths(['foo/bar.h'])
    end

    it 'throws an error is the headers are not found' do
      expect {
        subject.include_paths(['foo/bar.h'])
      }.to raise_error(RuntimeError, /Can't find header/)
    end
  end
end

describe Compiler::GCC do

  subject { Compiler::GCC.new }

  context '.framework_path' do
    it 'returns a path with the framework and QT version' do
      path = Compiler::GCC.framework_path('foo', '1.2.3')

      expect(path).to match(%r(Library/Frameworks/foo.*?/1.2.3/))
    end
  end

  context 'default_include_paths' do
    let(:include_paths) do
      %w(
 /usr/include/c++/4.6
 /usr/include/c++/4.6/x86_64-linux-gnu/.
 /usr/include/c++/4.6/backward
 /usr/lib/gcc/x86_64-linux-gnu/4.6/include
 /usr/local/include
 /usr/lib/gcc/x86_64-linux-gnu/4.6/include-fixed
 /usr/include/x86_64-linux-gnu
 /usr/include
      )
    end

    let(:gcc_output) do
      <<-EOT
Using built-in specs.
COLLECT_GCC=gcc
COLLECT_LTO_WRAPPER=/usr/lib/gcc/x86_64-linux-gnu/4.6/lto-wrapper
Target: x86_64-linux-gnu
Configured with: ../src/configure -v --with-pkgversion='Ubuntu/Linaro 4.6.3-1ubuntu5' --with-bugurl=file:///usr/share/doc/gcc-4.6/README.Bugs --enable-languages=c,c++,fortran,objc,obj-c++ --prefix=/usr --program-suffix=-4.6 --enable-shared --enable-linker-build-id --with-system-zlib --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --with-gxx-include-dir=/usr/include/c++/4.6 --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --enable-gnu-unique-object --enable-plugin --enable-objc-gc --disable-werror --with-arch-32=i686 --with-tune=generic --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu
Thread model: posix
gcc version 4.6.3 (Ubuntu/Linaro 4.6.3-1ubuntu5) 
COLLECT_GCC_OPTIONS='-v' '-E' '-mtune=generic' '-march=x86-64'
 /usr/lib/gcc/x86_64-linux-gnu/4.6/cc1plus -E -quiet -v -imultilib . -imultiarch x86_64-linux-gnu -D_GNU_SOURCE - -mtune=generic -march=x86-64 -fstack-protector
ignoring nonexistent directory "/usr/local/include/x86_64-linux-gnu"
ignoring nonexistent directory "/usr/lib/gcc/x86_64-linux-gnu/4.6/../../../../x86_64-linux-gnu/include"
#include "..." search starts here:
#include <...> search starts here:
 /usr/include/c++/4.6
 /usr/include/c++/4.6/x86_64-linux-gnu/.
 /usr/include/c++/4.6/backward
 /usr/lib/gcc/x86_64-linux-gnu/4.6/include
 /usr/local/include
 /usr/lib/gcc/x86_64-linux-gnu/4.6/include-fixed
 /usr/include/x86_64-linux-gnu
 /usr/include
End of search list.
COMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/4.6/:/usr/lib/gcc/x86_64-linux-gnu/4.6/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/4.6/:/usr/lib/gcc/x86_64-linux-gnu/
LIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/4.6/:/usr/lib/gcc/x86_64-linux-gnu/4.6/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/4.6/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/4.6/../../../:/lib/:/usr/lib/
COLLECT_GCC_OPTIONS='-v' '-E' '-mtune=generic' '-march=x86-64'
      EOT
    end

    before { subject.stub(:`).with(/gcc/).and_return(gcc_output) }

    it 'calls gcc' do
      subject.should_receive(:`).with(/gcc/).and_return(gcc_output)

      subject.default_include_paths('c++')
    end

    it 'parses gcc output' do
      actual = subject.default_include_paths('c++')

      expect(actual).to eq(include_paths)
    end
  end

  context 'missing_headers' do
    let(:makedepend_output) do
      <<-EOT
makedepend: warning:  main.cpp (reading main.h, line 4): cannot find include file "baz.h"
        not in /usr/include/iostream
      EOT
    end

    before { subject.stub(:`).with(/makedepend/).and_return(makedepend_output) }

    it 'calls makedepend' do
      subject.should_receive(:`).with(/makedepend/).and_return(makedepend_output)

      subject.missing_headers(['/foo'], ['bar.cpp'])
    end

    it 'returns missing headers' do
      missing = subject.missing_headers(['/foo'], ['bar.cpp'])

      expect(missing).to eq(['baz.h'])
    end
  end
end

