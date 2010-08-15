#include "main.h"

int main( int argc, char *argv[] ) {
  FILE * file = fopen ( "rake-c-testfile.txt", "w" );
  if( file == NULL )
    return 1;

  fputs( "rake-cpp test", file );
  fclose( file );

  return 0;
}
