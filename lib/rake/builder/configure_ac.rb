class Rake::Builder
  class ConfigureAc
    # source_file - the relative path to any one source file in the project
    def initialize(project_title, version, source_file)
      @project_title, @version, @source_file = project_title, version, source_file
    end

    def to_s
      <<EOT
AC_PREREQ(2.61)
AC_INIT(#{@project_title}, #{@version})
AC_CONFIG_SRCDIR([#{@source_file}])
AC_CONFIG_HEADER([config.h])
AM_INIT_AUTOMAKE([#{@project_title}], [#{@version}])

# Checks for programs.
AC_PROG_CXX
AC_PROG_CC
AC_PROG_RANLIB

# Checks for libraries.

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.
AC_HEADER_STDBOOL
AC_C_CONST
AC_C_INLINE
AC_STRUCT_TM

# Checks for library functions.
AC_FUNC_LSTAT
AC_FUNC_LSTAT_FOLLOWS_SLASHED_SYMLINK
AC_FUNC_MEMCMP
AC_HEADER_STDC
AC_CHECK_FUNCS([memset strcasecmp])

AC_CONFIG_FILES([Makefile])

AC_OUTPUT
EOT
    end

    def save
      File.open('configure.ac', 'w') do |f|
        f.write to_s
      end
    end
  end
end

