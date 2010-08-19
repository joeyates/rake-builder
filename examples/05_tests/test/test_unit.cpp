#include <assert.h>
#include <iostream>
#include "units.h"

int main( int argc, char *argv[] ) {
  Unit unit;
  assert( unit.to_string() == "Mile" );
  cout << "." << endl;
  cout << "All tests passed" << endl;

  return 0;
}
