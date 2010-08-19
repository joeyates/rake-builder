#ifndef __UNITS_H__
#define __UNITS_H__

#include <ostream>;
#include <string>;
using namespace std;

class Unit
{
  friend ostream &operator<<( ostream &out, Unit &unit );
 public:
  Unit() : name( "Mile" ) {}
  string to_string();
 private:
  string name;
};

#endif // ndef __UNITS_H__
