#include "main.h"

int main(int argc, char *argv[]) {
  ofstream outfile( "testfile.txt" );

  if( outfile.fail() )
    return 1;

  outfile << "rake/cpp test";

  cout << "Done";
  return 0;
}
