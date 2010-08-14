#include "main.h"

int main( int argc, char *argv[] ) {
  printf( "The contents of this directory:\n" );

  DIR *directory = opendir( "." );
  if( directory == NULL ) {
    puts( "Can't read directory" );
    return 1;
  }
  while( struct dirent * file = readdir( directory ) ) {
    puts( file->d_name );
  }
  closedir( directory );

  return 0;
}
