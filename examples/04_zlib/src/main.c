#include "main.h"

int main( int argc, char *argv[] ) {
  gzFile gzip;

  gzip = gzopen("rake.gz", "w");
  gzprintf( gzip, "Hello!" );
  gzclose( gzip );

  return 0;
}
