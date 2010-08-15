#include "main.h"

int main( int argc, char *argv[] ) {
  ofstream outfile( "rake-cpp-testfile.txt" );

  if( outfile.fail() )
    return 1;

  outfile << "rake-cpp test";

  return 0;
}
