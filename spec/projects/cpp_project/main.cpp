#include "main.h"

int main( int argc, char *argv[] ) {
  ofstream outfile( "rake-builder-testfile.txt" );

  if( outfile.fail() )
    return 1;

  outfile << "rake-builder test";

  return 0;
}
