#include "units.h"

ostream &operator<<( ostream &out, Unit &unit )
{
  out << unit.name;
  return out;
}

string Unit::to_string()
{
  return name;
}

